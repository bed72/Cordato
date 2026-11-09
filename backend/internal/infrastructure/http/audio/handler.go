package audio

import (
	"errors"
	"io"
	"mime"
	"net/http"
	"strings"

	"cordato/backend/internal/application/audio"

	"ganigeorgiev.com/pocketbase/pocketbase/apis"
	"ganigeorgiev.com/pocketbase/pocketbase/core"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/router"
)

type Acceptor interface {
	Execute(audio.Input) error
}

func Register(routes *router.Router[*core.RequestEvent], accept Acceptor) {
	limit := apis.BodyLimit(audio.MaxBytes)
	limit.Priority = 1
	routes.POST("/api/collections/audio/process", handle(accept)).
		Bind(apis.RequireAuth("users")).
		BindFunc(authorizeAndCheckHeaders).
		Bind(limit)
}

func authorizeAndCheckHeaders(e *core.RequestEvent) error {
	if !e.Auth.Verified() {
		return e.ForbiddenError("E-mail não verificado.", nil)
	}

	mediaType, _, err := mime.ParseMediaType(e.Request.Header.Get("Content-Type"))
	if err != nil || mediaType != "audio/mp4" {
		return router.NewApiError(http.StatusUnsupportedMediaType, "Tipo de áudio não suportado.", nil)
	}

	encodings := e.Request.Header.Values("Content-Encoding")
	if len(encodings) > 1 || (len(encodings) == 1 && !strings.EqualFold(strings.TrimSpace(encodings[0]), "identity")) {
		return router.NewApiError(http.StatusUnsupportedMediaType, "Codificação não suportada.", nil)
	}

	return e.Next()
}

func handle(accept Acceptor) func(*core.RequestEvent) error {
	return func(e *core.RequestEvent) error {
		content, err := io.ReadAll(e.Request.Body)
		if errors.Is(err, apis.ErrRequestEntityTooLarge) {
			return apis.ErrRequestEntityTooLarge
		}
		if err != nil || (e.Request.ContentLength > 0 && int64(len(content)) != e.Request.ContentLength) {
			return e.BadRequestError("Leitura de áudio incompleta.", nil)
		}

		if err := accept.Execute(audio.Input{Content: content}); err != nil {
			switch {
			case errors.Is(err, audio.ErrEmpty):
				return e.BadRequestError("Conteúdo de áudio vazio.", nil)
			case errors.Is(err, audio.ErrTooLarge):
				return apis.ErrRequestEntityTooLarge
			default:
				return e.InternalServerError("Não foi possível aceitar o áudio.", nil)
			}
		}

		return e.JSON(http.StatusAccepted, map[string]string{"status": "accepted"})
	}
}
