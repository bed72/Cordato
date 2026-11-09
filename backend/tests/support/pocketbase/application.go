package pocketbase

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"cordato/backend/internal/bootstrap"

	pb "ganigeorgiev.com/pocketbase/pocketbase"
	"ganigeorgiev.com/pocketbase/pocketbase/core"
	"ganigeorgiev.com/pocketbase/pocketbase/tests"
)

func NewApplication(t *testing.T) *pb.PocketBase {
	t.Helper()
	app := NewConfiguredApplication(t)
	if err := app.Bootstrap(); err != nil {
		t.Fatal(err)
	}
	if err := app.RunAllMigrations(); err != nil {
		t.Fatal(err)
	}
	if err := app.ReloadSettings(); err != nil {
		t.Fatal(err)
	}
	app.Settings().Logs.MaxDays = 0
	return app
}

func NewConfiguredApplication(t *testing.T) *pb.PocketBase {
	t.Helper()
	sourceDir := BackendRoot(t)
	workspace := t.TempDir()
	if err := os.CopyFS(filepath.Join(workspace, "pb_migrations"), os.DirFS(filepath.Join(sourceDir, "pb_migrations"))); err != nil {
		t.Fatal(err)
	}
	t.Chdir(workspace)
	t.Setenv("POCKETBASE_PUBLIC_URL", "https://backend.example.test")
	t.Setenv("POCKETBASE_ADMIN_EMAIL", "admin@example.test")
	t.Setenv("POCKETBASE_ADMIN_PASSWORD", "TestAdmin123456")
	t.Setenv("SMTP_PASSWORD", "fictitious-smtp-password")
	t.Setenv("POCKETBASE_ENCRYPTION_KEY", strings.Repeat("x", 32))

	savedMigrations := core.AppMigrations
	core.AppMigrations = core.MigrationsList{}
	t.Cleanup(func() { core.AppMigrations = savedMigrations })

	app, err := bootstrap.New(pb.Config{DefaultDataDir: t.TempDir()})
	if err != nil {
		t.Fatal(err)
	}
	mailbox := &tests.TestMailer{}
	app.OnMailerSend().BindFunc(func(e *core.MailerEvent) error {
		e.Mailer = mailbox
		return e.Next()
	})
	t.Cleanup(func() {
		if err := app.ClearBootstrap(); err != nil {
			t.Error(err)
		}
	})
	return app
}
