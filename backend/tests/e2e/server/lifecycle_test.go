package server_test

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"syscall"
	"testing"
	"time"

	pbtest "cordato/backend/tests/support/pocketbase"
)

func TestLocalServerLifecycle(t *testing.T) {
	if os.Getenv("CORDATO_HTTP_SMOKE") != "1" {
		t.Skip("habilite CORDATO_HTTP_SMOKE=1 para validar o executável em loopback")
	}

	sourceDir := pbtest.BackendRoot(t)
	binary := filepath.Join(t.TempDir(), "cordato")
	buildContext, cancelBuild := context.WithTimeout(t.Context(), 2*time.Minute)
	defer cancelBuild()
	build := exec.CommandContext(buildContext, "go", "build", "-o", binary, "./cmd/cordato")
	build.Dir = sourceDir
	if err := build.Run(); err != nil {
		t.Fatalf("build do executável: %v", err)
	}

	app := pbtest.NewConfiguredApplication(t)
	client := &http.Client{
		Timeout:   3 * time.Second,
		Transport: &http.Transport{Proxy: nil},
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			return http.ErrUseLastResponse
		},
	}
	t.Cleanup(client.CloseIdleConnections)
	baseURL, stop := startLocalServer(t, binary, app.DataDir(), client)
	liveRequest(t, client, baseURL, http.MethodGet, "/_/", "", "", http.StatusOK)
	liveRequestWithType(t, client, baseURL, http.MethodPost, "/api/collections/audio/process", "", "synthetic-not-m4a", "audio/mp4", http.StatusUnauthorized)
	stop()
	t.Log("executável iniciou em loopback, aplicou a migration e serviu painel/rotas")

	if err := app.Bootstrap(); err != nil {
		t.Fatal(err)
	}
	if pbtest.MigrationCount(t, app) != 1 {
		t.Fatal("serve não aplicou a migration inicial exatamente uma vez")
	}
	owner := pbtest.CreateUser(t, app, "http-owner@example.test", true)
	other := pbtest.CreateUser(t, app, "http-other@example.test", true)
	settings, err := app.Settings().Clone()
	if err != nil {
		t.Fatal(err)
	}
	settings.SMTP.Host = "127.0.0.1"
	settings.SMTP.Port = 1
	if err := app.Save(settings); err != nil {
		t.Fatal(err)
	}
	if err := app.ClearBootstrap(); err != nil {
		t.Fatal(err)
	}
	t.Setenv("POCKETBASE_ADMIN_EMAIL", "")
	t.Setenv("POCKETBASE_ADMIN_PASSWORD", "")
	t.Setenv("SMTP_PASSWORD", "")

	baseURL, stop = startLocalServer(t, binary, app.DataDir(), client)
	if os.Getenv("CORDATO_BRUNO_SMOKE") == "1" {
		runBrunoContract(t, sourceDir, baseURL, owner.Email())
	}
	ownerToken := liveLogin(t, client, baseURL, owner.Email())
	otherToken := liveLogin(t, client, baseURL, other.Email())
	const audioPath = "/api/collections/audio/process"
	liveRequestWithType(t, client, baseURL, http.MethodPost, audioPath, "", "synthetic-not-m4a", "audio/mp4", http.StatusUnauthorized)
	liveRequestWithType(t, client, baseURL, http.MethodPost, audioPath, ownerToken, "synthetic-not-m4a", "application/json", http.StatusUnsupportedMediaType)
	acceptedAudio := liveDecode[struct{ Status string }](t,
		liveRequestWithType(t, client, baseURL, http.MethodPost, audioPath, ownerToken, "synthetic-not-m4a", "audio/mp4", http.StatusAccepted))
	if acceptedAudio.Status != "accepted" {
		t.Fatal("aceite de áudio HTTP inesperado")
	}
	const records = "/api/collections/expenses/records"
	body := fmt.Sprintf(`{"owner":%q,"amount":2590,"description":"Almoço HTTP","category":"food","occurred_on":"2026-11-09 00:00:00.000Z"}`, owner.Id)
	created := liveDecode[struct{ ID string }](t,
		liveRequest(t, client, baseURL, http.MethodPost, records, ownerToken, body, http.StatusOK))
	if created.ID == "" {
		t.Fatal("cadastro HTTP não retornou ID")
	}
	path := records + "/" + created.ID
	liveRequest(t, client, baseURL, http.MethodGet, path, otherToken, "", http.StatusNotFound)
	liveRequest(t, client, baseURL, http.MethodPatch, path, otherToken, `{"amount":100}`, http.StatusNotFound)
	liveRequest(t, client, baseURL, http.MethodDelete, path, otherToken, "", http.StatusNotFound)
	liveRequest(t, client, baseURL, http.MethodPatch, path, ownerToken, `{"amount":3000}`, http.StatusOK)
	stop()
	t.Log("login, aceite/rejeição de áudio, criação, atualização e isolamento passaram por HTTP real")

	baseURL, stop = startLocalServer(t, binary, app.DataDir(), client)
	ownerToken = liveLogin(t, client, baseURL, owner.Email())
	persisted := liveDecode[struct {
		Owner  string
		Amount int64
	}](t, liveRequest(t, client, baseURL, http.MethodGet, path, ownerToken, "", http.StatusOK))
	if persisted.Owner != owner.Id || persisted.Amount != 3000 {
		t.Fatal("reinício não preservou a despesa atualizada")
	}
	liveRequest(t, client, baseURL, http.MethodDelete, path, ownerToken, "", http.StatusNoContent)
	liveRequest(t, client, baseURL, http.MethodGet, path, ownerToken, "", http.StatusNotFound)
	stop()

	if err := app.Bootstrap(); err != nil {
		t.Fatal(err)
	}
	if pbtest.MigrationCount(t, app) != 1 {
		t.Fatal("reinícios alteraram o histórico da migration inicial")
	}
	if _, err := app.FindRecordById("users", owner.Id); err != nil {
		t.Fatal("reinício não preservou o usuário")
	}
	t.Log("reinícios via SIGTERM preservaram dados e histórico; exclusão HTTP confirmada")
}

func startLocalServer(t *testing.T, binary, dataDir string, client *http.Client) (string, func()) {
	t.Helper()
	reservation, err := net.Listen("tcp4", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	address := reservation.Addr().String()
	if err := reservation.Close(); err != nil {
		t.Fatal(err)
	}
	command := exec.Command(binary, "serve", "--http="+address, "--dir="+dataDir,
		"--migrationsDir=pb_migrations", "--automigrate=false")
	if err := command.Start(); err != nil {
		t.Fatalf("início do servidor local: %v", err)
	}
	exited := make(chan error, 1)
	go func() { exited <- command.Wait() }()
	shutdown := &sync.Once{}
	stop := func() {
		t.Helper()
		shutdown.Do(func() {
			select {
			case err := <-exited:
				t.Errorf("servidor encerrou antes do SIGTERM: %v", err)
				return
			default:
			}
			if err := command.Process.Signal(syscall.SIGTERM); err != nil {
				t.Errorf("SIGTERM: %v", err)
				_ = command.Process.Kill()
				<-exited
				return
			}
			timer := time.NewTimer(10 * time.Second)
			defer timer.Stop()
			select {
			case err := <-exited:
				if err != nil {
					t.Errorf("encerramento do servidor: %v", err)
				}
			case <-timer.C:
				_ = command.Process.Kill()
				<-exited
				t.Error("servidor não encerrou após SIGTERM")
			}
		})
	}
	t.Cleanup(stop)
	baseURL := "http://" + address
	deadline := time.NewTimer(15 * time.Second)
	defer deadline.Stop()
	probe := time.NewTicker(50 * time.Millisecond)
	defer probe.Stop()
	for {
		select {
		case err := <-exited:
			shutdown.Do(func() {})
			t.Fatalf("servidor encerrou durante inicialização: %v", err)
		case <-deadline.C:
			t.Fatal("servidor não ficou saudável no prazo")
		case <-probe.C:
			response, err := client.Get(baseURL + "/api/health")
			if err != nil {
				continue
			}
			_ = response.Body.Close()
			if response.StatusCode == http.StatusOK {
				return baseURL, stop
			}
		}
	}
}

func liveRequest(t *testing.T, client *http.Client, baseURL, method, path, token, body string, status int) []byte {
	t.Helper()
	return liveRequestWithType(t, client, baseURL, method, path, token, body, "application/json", status)
}

func liveRequestWithType(t *testing.T, client *http.Client, baseURL, method, path, token, body, mediaType string, status int) []byte {
	t.Helper()
	req, err := http.NewRequestWithContext(t.Context(), method, baseURL+path, strings.NewReader(body))
	if err != nil {
		t.Fatal("requisição HTTP inválida")
	}
	req.Header.Set("Content-Type", mediaType)
	if token != "" {
		req.Header.Set("Authorization", token)
	}
	response, err := client.Do(req)
	if err != nil {
		t.Fatalf("%s %s: falha HTTP local", method, path)
	}
	defer response.Body.Close()
	if response.StatusCode != status {
		t.Fatalf("%s %s: status %d, esperado %d", method, path, response.StatusCode, status)
	}
	payload, err := io.ReadAll(response.Body)
	if err != nil {
		t.Fatal("falha ao ler resposta HTTP local")
	}
	return payload
}

func liveDecode[T any](t *testing.T, payload []byte) T {
	t.Helper()
	decoded := *new(T)
	if err := json.Unmarshal(payload, &decoded); err != nil {
		t.Fatal("JSON HTTP inválido")
	}
	return decoded
}

func liveLogin(t *testing.T, client *http.Client, baseURL, email string) string {
	t.Helper()
	auth := liveDecode[struct{ Token string }](t, liveRequest(t, client, baseURL,
		http.MethodPost, "/api/collections/users/auth-with-password", "",
		`{"identity":"`+email+`","password":"Cordato123"}`, http.StatusOK))
	if auth.Token == "" {
		t.Fatal("login HTTP não retornou token")
	}
	return auth.Token
}
