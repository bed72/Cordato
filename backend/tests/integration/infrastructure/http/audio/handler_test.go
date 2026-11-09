package audio_test

import (
	"bytes"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"cordato/backend/internal/application/audio"
)

func TestAuthorizationBeforeBody(t *testing.T) {
	spy := &acceptSpy{}
	handler, verified, unverified, admin := audioHandler(t, spy)
	for _, scenario := range []struct {
		name   string
		token  string
		status int
	}{
		{"absent", "", 401},
		{"invalid", "private-token", 401},
		{"unverified", unverified, 403},
		{"other-collection", admin, 403},
	} {
		t.Run(scenario.name, func(t *testing.T) {
			body := &countingBody{reader: endlessReader{}}
			response := sendAudio(handler, scenario.token, "application/json", nil, body, 100*audio.MaxBytes)
			assertAudioStatus(t, response, scenario.status)
			if body.reads != 0 || spy.calls != 0 {
				t.Fatal("rejeição de autorização consumiu conteúdo")
			}
		})
	}
	body := &countingBody{reader: strings.NewReader("synthetic")}
	assertAudioStatus(t, sendAudio(handler, verified, "audio/mp4", nil, body, -1), 202)
}

func TestMediaHeaders(t *testing.T) {
	spy := &acceptSpy{}
	handler, token, _, _ := audioHandler(t, spy)
	for _, scenario := range []struct {
		name      string
		mediaType string
		encodings []string
		status    int
	}{
		{"missing", "", nil, 415},
		{"malformed", "audio/mp4; codecs=", nil, 415},
		{"m4a", "audio/m4a", nil, 415},
		{"aac", "audio/aac", nil, 415},
		{"wav", "audio/wav", nil, 415},
		{"json", "application/json", nil, 415},
		{"multipart", "multipart/form-data; boundary=test", nil, 415},
		{"octet-stream", "application/octet-stream", nil, 415},
		{"gzip", "audio/mp4", []string{"gzip"}, 415},
		{"encoding-list", "audio/mp4", []string{"identity, gzip"}, 415},
		{"encoding-headers", "audio/mp4", []string{"identity", "gzip"}, 415},
		{"empty-encoding", "audio/mp4", []string{""}, 415},
		{"plain", "audio/mp4", nil, 202},
		{"case", "AuDiO/MP4", nil, 202},
		{"parameters", `audio/mp4; codecs="mp4a.40.2"; custom=value`, nil, 202},
		{"identity", "audio/mp4", []string{"IdEnTiTy"}, 202},
	} {
		t.Run(scenario.name, func(t *testing.T) {
			spy.calls = 0
			body := &countingBody{reader: strings.NewReader("synthetic-not-m4a")}
			length := int64(-1)
			if scenario.status == 415 {
				length = 100 * audio.MaxBytes
			}
			response := sendAudio(handler, token, scenario.mediaType, scenario.encodings, body, length)
			assertAudioStatus(t, response, scenario.status)
			if scenario.status == 415 {
				if body.reads != 0 || spy.calls != 0 {
					t.Fatal("headers rejeitados consumiram conteúdo")
				}
				return
			}
			if spy.calls != 1 || string(spy.content) != "synthetic-not-m4a" {
				t.Fatal("delegação inválida")
			}
		})
	}
}

func TestBodyBoundaries(t *testing.T) {
	spy := &acceptSpy{}
	handler, token, _, _ := audioHandler(t, spy)
	for _, scenario := range []struct {
		name    string
		reader  io.Reader
		length  int64
		status  int
		calls   int
		maxRead int
	}{
		{"empty-known", strings.NewReader(""), 0, 400, 1, 0},
		{"empty-unknown", strings.NewReader(""), -1, 400, 1, 0},
		{"small-known", strings.NewReader("synthetic"), 9, 202, 1, 9},
		{"small-unknown", strings.NewReader("synthetic"), -1, 202, 1, 9},
		{"exact-known", bytes.NewReader(make([]byte, audio.MaxBytes)), audio.MaxBytes, 202, 1, audio.MaxBytes},
		{"exact-unknown", bytes.NewReader(make([]byte, audio.MaxBytes)), -1, 202, 1, audio.MaxBytes},
		{"excess-known", endlessReader{}, audio.MaxBytes + 1, 413, 0, 0},
		{"excess-unknown", endlessReader{}, -1, 413, 0, audio.MaxBytes + 1},
		{"false-small-length", endlessReader{}, 1, 413, 0, audio.MaxBytes + 1},
		{"partial-error", failingReader{errors.New("private-read-error")}, -1, 400, 0, 13},
		{"incomplete-transfer", failingReader{io.ErrUnexpectedEOF}, 100, 400, 0, 13},
		{"short-eof", strings.NewReader("synthetic"), 100, 400, 0, 9},
	} {
		t.Run(scenario.name, func(t *testing.T) {
			spy.calls = 0
			spy.content = nil
			body := &countingBody{reader: scenario.reader}
			response := sendAudio(handler, token, "audio/mp4", nil, body, scenario.length)
			assertAudioStatus(t, response, scenario.status)
			if spy.calls != scenario.calls || body.bytes > scenario.maxRead {
				t.Fatalf("delegações %d, bytes lidos %d", spy.calls, body.bytes)
			}
		})
	}
}

func TestWaitsForEOF(t *testing.T) {
	spy := &acceptSpy{}
	handler, token, _, _ := audioHandler(t, spy)
	response := httptest.NewRecorder()
	body := &gatedBody{started: make(chan struct{}), release: make(chan struct{})}
	body.beforeEOF = func() {
		if spy.calls != 0 || response.Code != http.StatusOK || response.Body.Len() != 0 || response.Flushed {
			t.Error("aceite publicado antes do EOF")
		}
	}
	req := httptest.NewRequest(http.MethodPost, "/api/collections/audio/process", nil)
	req.Body = body
	req.ContentLength = -1
	req.Header.Set("Authorization", token)
	req.Header.Set("Content-Type", "audio/mp4")
	done := make(chan struct{})
	go func() {
		defer close(done)
		handler.ServeHTTP(response, req)
	}()
	<-body.started
	close(body.release)
	<-done
	assertAudioStatus(t, response, 202)
	if spy.calls != 1 || string(spy.content) != "synthetic-not-m4a" {
		t.Fatal("conteúdo incompleto ou delegação repetida")
	}
}

func TestApplicationFailuresRemainSafe(t *testing.T) {
	spy := &acceptSpy{}
	handler, token, _, _ := audioHandler(t, spy)
	for _, scenario := range []struct {
		name    string
		failure error
		status  int
	}{
		{"empty", audio.ErrEmpty, 400},
		{"excess", audio.ErrTooLarge, 413},
		{"unexpected", errors.New("private-read-error"), 500},
	} {
		t.Run(scenario.name, func(t *testing.T) {
			spy.failure = scenario.failure
			spy.calls = 0
			body := &countingBody{reader: strings.NewReader("synthetic-not-m4a")}
			assertAudioStatus(t, sendAudio(handler, token, "audio/mp4", nil, body, -1), scenario.status)
			if spy.calls != 1 {
				t.Fatal("falha de aplicação repetiu delegação")
			}
		})
	}
}
