# All comments are in English

serve:
	hugo server -D

build:
	hugo --minify

clean:
	rm -rf public resources .hugo_build.lock
	hugo mod clean

tidy:
	hugo mod tidy
