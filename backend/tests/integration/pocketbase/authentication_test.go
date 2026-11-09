package pocketbase_test

import (
	"net/http"
	"net/url"
	"regexp"
	"testing"
	"time"

	pbtest "cordato/backend/tests/support/pocketbase"

	"ganigeorgiev.com/pocketbase/pocketbase/core"
	"ganigeorgiev.com/pocketbase/pocketbase/tests"
)

func TestRegistrationVerificationAndAuthentication(t *testing.T) {
	app := pbtest.NewApplication(t)
	mailbox := &tests.TestMailer{}
	sent := make(chan struct{}, 1)
	app.OnMailerSend().BindFunc(func(e *core.MailerEvent) error {
		e.Mailer = mailbox
		err := e.Next()
		sent <- struct{}{}
		return err
	})
	handler := pbtest.NewHandler(t, app)
	pbtest.Request(t, handler, http.MethodPost, "/api/collections/users/records", "",
		`{"email":"new@example.test","password":"Cordato123","passwordConfirm":"Cordato123"}`, http.StatusOK)
	pbtest.Request(t, handler, http.MethodPost, "/api/collections/users/auth-with-password", "",
		`{"identity":"new@example.test","password":"Cordato123"}`, http.StatusForbidden)
	pbtest.Request(t, handler, http.MethodPost, "/api/collections/users/request-verification", "",
		`{"email":"new@example.test"}`, http.StatusNoContent)
	select {
	case <-sent:
	case <-time.After(10 * time.Second):
		t.Fatal("envio simulado não concluiu")
	}
	if mailbox.TotalSend() != 1 {
		t.Fatal("esperado exatamente um e-mail simulado")
	}
	message := mailbox.FirstMessage()
	link := regexp.MustCompile(`https://app\.cordato\.cloud/authentication/confirm-email\?token=([^"<\s]+)`).FindStringSubmatch(message.HTML)
	if len(link) != 2 {
		t.Fatal("e-mail não contém o link de verificação do app")
	}
	token, err := url.QueryUnescape(link[1])
	if err != nil {
		t.Fatal("token de verificação inválido")
	}
	pbtest.Request(t, handler, http.MethodPost, "/api/collections/users/confirm-verification", "",
		`{"token":"`+token+`"}`, http.StatusNoContent)
	authToken := pbtest.Login(t, handler, "new@example.test")
	pbtest.Request(t, handler, http.MethodPost, "/api/collections/users/auth-refresh", authToken, "", http.StatusOK)
	pbtest.Request(t, handler, http.MethodPost, "/api/collections/users/auth-with-password", "",
		`{"identity":"new@example.test","password":"Wrong123"}`, http.StatusBadRequest)
}

func TestNativeRoutesRemainAvailable(t *testing.T) {
	app := pbtest.NewApplication(t)
	handler := pbtest.NewHandler(t, app)
	pbtest.Request(t, handler, http.MethodGet, "/api/health", "", "", http.StatusOK)
	pbtest.Request(t, handler, http.MethodGet, "/_/", "", "", http.StatusOK)
}

func TestPOCHealthRouteWasRemoved(t *testing.T) {
	app := pbtest.NewApplication(t)
	handler := pbtest.NewHandler(t, app)
	pbtest.Request(t, handler, http.MethodGet, "/api/cordato/health", "", "", http.StatusNotFound)
}
