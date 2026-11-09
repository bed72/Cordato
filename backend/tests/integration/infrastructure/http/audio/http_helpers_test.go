package audio_test

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func sendAudio(handler http.Handler, token, mediaType string, encodings []string, body io.ReadCloser, length int64) *httptest.ResponseRecorder {
	req := httptest.NewRequest(http.MethodPost, "/api/collections/audio/process", nil)
	req.Body = body
	req.ContentLength = length
	req.Header.Set("Authorization", token)
	req.Header.Set("Content-Type", mediaType)
	if encodings != nil {
		req.Header["Content-Encoding"] = encodings
	}
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, req)
	return response
}

func assertAudioStatus(t *testing.T, response *httptest.ResponseRecorder, status int) {
	t.Helper()
	if response.Code != status {
		t.Fatalf("status %d, esperado %d: %s", response.Code, status, response.Body.String())
	}
	if status == http.StatusAccepted {
		if strings.TrimSpace(response.Body.String()) != `{"status":"accepted"}` || response.Header().Get("Location") != "" {
			t.Fatal("resposta de aceite inesperada")
		}
		return
	}
	payload := struct {
		Status  int            `json:"status"`
		Message string         `json:"message"`
		Data    map[string]any `json:"data"`
	}{}
	if err := json.Unmarshal(response.Body.Bytes(), &payload); err != nil {
		t.Fatal(err)
	}
	if payload.Status != status || payload.Message == "" || len(payload.Data) != 0 {
		t.Fatal("envelope de erro inseguro ou inválido")
	}
	for _, secret := range []string{"private-audio", "private-read-error", "private-token"} {
		if strings.Contains(response.Body.String(), secret) {
			t.Fatal("resposta expôs conteúdo privado")
		}
	}
}
