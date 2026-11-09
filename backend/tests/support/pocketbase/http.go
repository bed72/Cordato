package pocketbase

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"ganigeorgiev.com/pocketbase/pocketbase/apis"
	"ganigeorgiev.com/pocketbase/pocketbase/core"
	"ganigeorgiev.com/pocketbase/pocketbase/ui"
)

func NewHandler(t *testing.T, app core.App) http.Handler {
	t.Helper()
	routes, err := apis.NewRouter(app)
	if err != nil {
		t.Fatal(err)
	}
	routes.GET("/_/{path...}", apis.Static(ui.DistDirFS, false))
	event := &core.ServeEvent{App: app, Router: routes}
	if err := app.OnServe().Trigger(event); err != nil {
		t.Fatal(err)
	}
	handler, err := routes.BuildMux()
	if err != nil {
		t.Fatal(err)
	}
	return handler
}

func Request(t *testing.T, handler http.Handler, method, path, token, body string, status int) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(method, path, strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	if token != "" {
		req.Header.Set("Authorization", token)
	}
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, req)
	if response.Code != status {
		t.Fatalf("%s %s: status %d, esperado %d", method, path, response.Code, status)
	}
	return response
}

func Decode[T any](t *testing.T, response *httptest.ResponseRecorder) T {
	t.Helper()
	payload := *new(T)
	if err := json.Unmarshal(response.Body.Bytes(), &payload); err != nil {
		t.Fatal(err)
	}
	return payload
}

func Login(t *testing.T, handler http.Handler, email string) string {
	t.Helper()
	response := Request(t, handler, http.MethodPost, "/api/collections/users/auth-with-password", "",
		`{"identity":"`+email+`","password":"Cordato123"}`, http.StatusOK)
	auth := Decode[struct{ Token string }](t, response)
	if auth.Token == "" {
		t.Fatal("login não retornou token")
	}
	return auth.Token
}
