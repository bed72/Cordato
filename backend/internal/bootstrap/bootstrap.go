package bootstrap

import (
	"errors"
	"os"
	"path/filepath"

	"cordato/backend/internal/application/audio"
	audiohttp "cordato/backend/internal/infrastructure/http/audio"

	pb "ganigeorgiev.com/pocketbase/pocketbase"
	"ganigeorgiev.com/pocketbase/pocketbase/apis"
	"ganigeorgiev.com/pocketbase/pocketbase/core"
	"ganigeorgiev.com/pocketbase/pocketbase/plugins/jsvm"
	"ganigeorgiev.com/pocketbase/pocketbase/plugins/migratecmd"
	"github.com/spf13/pflag"
)

func New(config pb.Config) (*pb.PocketBase, error) {
	if config.DefaultDataDir == "" {
		config.DefaultDataDir = ".temp/cordato/pb_data"
	}

	config.DefaultEncryptionEnv = "POCKETBASE_ENCRYPTION_KEY"
	config.DefaultDev = false
	app := pb.NewWithConfig(config)

	migrationsDir := "pb_migrations"
	hooksDir := filepath.Join(app.DataDir(), "no-hooks")
	publicDir := filepath.Join(app.DataDir(), "no-public")
	automigrate := false
	flags := app.RootCmd.PersistentFlags()
	flags.StringVar(&migrationsDir, "migrationsDir", migrationsDir, "diretório das migrations JavaScript")
	flags.StringVar(&hooksDir, "hooksDir", hooksDir, "diretório reservado; hooks JavaScript estão desabilitados")
	flags.StringVar(&publicDir, "publicDir", publicDir, "diretório de arquivos públicos")
	flags.BoolVar(&automigrate, "automigrate", false, "gerar migrations automaticamente pelo painel")
	if err := app.RootCmd.ParseFlags(os.Args[1:]); err != nil && !errors.Is(err, pflag.ErrHelp) {
		return nil, err
	}

	if err := jsvm.Register(app, jsvm.Config{
		MigrationsDir:     migrationsDir,
		HooksDir:          hooksDir,
		HooksFilesPattern: "a^",
	}); err != nil {
		return nil, err
	}

	if err := migratecmd.Register(app, app.RootCmd, migratecmd.Config{
		Dir:          migrationsDir,
		TemplateLang: migratecmd.TemplateLangJS,
		Automigrate:  automigrate,
	}); err != nil {
		return nil, err
	}

	app.OnBootstrap().BindFunc(func(e *core.BootstrapEvent) error {
		if e.App.EncryptionEnv() != "POCKETBASE_ENCRYPTION_KEY" || len(os.Getenv("POCKETBASE_ENCRYPTION_KEY")) != 32 {
			return errors.New("POCKETBASE_ENCRYPTION_KEY deve conter exatamente 32 bytes e ser a chave configurada")
		}

		return e.Next()
	})

	app.OnServe().BindFunc(func(e *core.ServeEvent) error {
		audiohttp.Register(e.Router, audio.UseCase{})
		e.Router.GET("/{path...}", apis.Static(os.DirFS(publicDir), false))

		return e.Next()
	})

	app.RootCmd.SetVersionTemplate("{{.Version}}\n")
	app.RootCmd.Version = "cordato (PocketBase 0.41.1)"

	return app, nil
}
