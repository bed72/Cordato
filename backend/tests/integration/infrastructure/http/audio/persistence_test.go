package audio_test

import (
	"crypto/sha256"
	"io/fs"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"

	pbtest "cordato/backend/tests/support/pocketbase"

	"ganigeorgiev.com/pocketbase/pocketbase/core"
)

func TestAudioIntakeDoesNotPersist(t *testing.T) {
	app := pbtest.NewApplication(t)
	owner := pbtest.CreateUser(t, app, "audio-owner@example.test", true)
	token, err := owner.NewAuthToken()
	if err != nil {
		t.Fatal(err)
	}
	handler := pbtest.NewHandler(t, app)
	beforeFiles := audioStorageSnapshot(t, app.DataDir())
	beforeExpenses, err := app.CountRecords("expenses")
	if err != nil {
		t.Fatal(err)
	}
	writes := 0
	trackWrite := func(e *core.RecordEvent) error {
		writes++
		return e.Next()
	}
	app.OnRecordCreate().BindFunc(trackWrite)
	app.OnRecordUpdate().BindFunc(trackWrite)
	app.OnRecordDelete().BindFunc(trackWrite)
	for range 2 {
		req := httptest.NewRequest(http.MethodPost, "/api/collections/audio/process", strings.NewReader("synthetic-not-m4a"))
		req.Header.Set("Content-Type", "audio/mp4")
		req.Header.Set("Authorization", token)
		response := httptest.NewRecorder()
		handler.ServeHTTP(response, req)
		if response.Code != http.StatusAccepted || strings.TrimSpace(response.Body.String()) != `{"status":"accepted"}` {
			t.Fatal("contrato de aceite não foi preservado na composição")
		}
	}
	if writes != 0 {
		t.Fatal("aceite escreveu records")
	}
	afterExpenses, err := app.CountRecords("expenses")
	if err != nil || beforeExpenses != afterExpenses {
		t.Fatal("aceite alterou despesas")
	}
	if _, err := app.FindCollectionByNameOrId("audio"); err == nil {
		t.Fatal("collection de áudio não deveria existir")
	}
	if !reflect.DeepEqual(beforeFiles, audioStorageSnapshot(t, app.DataDir())) {
		t.Fatal("aceite criou ou alterou arquivos fora do banco")
	}
	pbtest.Request(t, handler, http.MethodGet, "/api/health", "", "", http.StatusOK)
	pbtest.Request(t, handler, http.MethodGet, "/api/collections/expenses/records", token, "", http.StatusOK)
	pbtest.Request(t, handler, http.MethodGet, "/api/collections/metrics/records", token, "", http.StatusOK)
}

func audioStorageSnapshot(t *testing.T, directory string) map[string][sha256.Size]byte {
	t.Helper()
	files := map[string][sha256.Size]byte{}
	err := filepath.WalkDir(directory, func(path string, entry fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if entry.IsDir() || strings.HasSuffix(path, ".db") || strings.Contains(path, ".db-") {
			return nil
		}
		content, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		files[path] = sha256.Sum256(content)
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	return files
}
