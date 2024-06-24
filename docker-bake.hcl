variable "PROMTAIL_VERSION" { default = "latest" }

target "docker-metadata-action" {}
target "github-metadata-action" {}

target "default" {
    inherits = [ "promtail" ]
    platforms = [
        "linux/amd64",
        "linux/arm64"
    ]
}

target "local" {
    inherits = [ "promtail" ]
    tags = [ "swarmlibs/promtail:local" ]
}

target "promtail" {
    context = "."
    dockerfile = "Dockerfile"
    inherits = [
        "docker-metadata-action",
        "github-metadata-action",
    ]
    args = {
        PROMTAIL_VERSION = "${PROMTAIL_VERSION}"
    }
}
