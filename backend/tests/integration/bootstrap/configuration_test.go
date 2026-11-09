package bootstrap_test

import (
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"

	pbtest "cordato/backend/tests/support/pocketbase"
)

func TestInvalidEncryptionKeyStopsBootstrap(t *testing.T) {
	for _, key := range []string{"", "short", "123456789012345678901234567890123", strings.Repeat("é", 32)} {
		t.Run("bytes-"+strconv.Itoa(len(key)), func(t *testing.T) {
			app := pbtest.NewConfiguredApplication(t)
			t.Setenv("POCKETBASE_ENCRYPTION_KEY", key)
			if err := app.Bootstrap(); err == nil {
				t.Fatal("bootstrap aceitou chave inválida")
			}
			if _, err := os.Stat(filepath.Join(app.DataDir(), "data.db")); !os.IsNotExist(err) {
				t.Fatal("bootstrap inválido não deve criar banco")
			}
		})
	}
}

func TestDashboardDoesNotGenerateMigrationsByDefault(t *testing.T) {
	app := pbtest.NewApplication(t)
	if app.IsDev() || app.EncryptionEnv() != "POCKETBASE_ENCRYPTION_KEY" {
		t.Fatal("defaults de segurança incompatíveis")
	}
	admin, err := app.FindAuthRecordByEmail("_superusers", "admin@example.test")
	if err != nil {
		t.Fatal(err)
	}
	token, err := admin.NewAuthToken()
	if err != nil {
		t.Fatal(err)
	}
	handler := pbtest.NewHandler(t, app)
	pbtest.Request(t, handler, http.MethodPatch, "/api/collections/expenses", token, `{"name":"expenses"}`, http.StatusOK)
	files, err := os.ReadDir("pb_migrations")
	if err != nil {
		t.Fatal(err)
	}
	if len(files) != 1 || files[0].Name() != "1793491200_initial.js" {
		t.Fatal("edição pelo painel gerou migration com automigrate desabilitado")
	}
	command, _, err := app.RootCmd.Find([]string{"migrate"})
	if err != nil || command.Name() != "migrate" {
		t.Fatal("comando migrate não registrado")
	}
}
