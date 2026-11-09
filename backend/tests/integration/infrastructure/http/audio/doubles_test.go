package audio_test

import (
	"io"

	"cordato/backend/internal/application/audio"
)

type acceptSpy struct {
	calls   int
	content []byte
	failure error
}

func (s *acceptSpy) Execute(input audio.Input) error {
	s.calls++
	s.content = append([]byte(nil), input.Content...)
	if s.failure != nil {
		return s.failure
	}
	return (audio.UseCase{}).Execute(input)
}

type countingBody struct {
	reader io.Reader
	reads  int
	bytes  int
}

func (b *countingBody) Read(p []byte) (int, error) {
	b.reads++
	n, err := b.reader.Read(p)
	b.bytes += n
	return n, err
}

func (*countingBody) Close() error { return nil }

type endlessReader struct{}

func (endlessReader) Read(p []byte) (int, error) {
	for i := range p {
		p[i] = 42
	}
	return len(p), nil
}

type failingReader struct {
	failure error
}

func (r failingReader) Read(p []byte) (int, error) {
	return copy(p, "private-audio"), r.failure
}

type gatedBody struct {
	started   chan struct{}
	release   chan struct{}
	read      bool
	beforeEOF func()
}

func (b *gatedBody) Read(p []byte) (int, error) {
	if !b.read {
		b.read = true
		return copy(p, "synthetic-not-m4a"), nil
	}
	close(b.started)
	<-b.release
	b.beforeEOF()
	return 0, io.EOF
}

func (*gatedBody) Close() error { return nil }
