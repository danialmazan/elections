project <- normalizePath(file.path(getwd(), "source/madrid_elections_2023"), mustWork=TRUE)
input <- file.path(project, "article.Rmd")
output <- file.path(getwd(), "madrid_elections_2023.html")
source <- readLines(input, warn=FALSE)
yaml_end <- which(source == "---")[2]
body <- source[(yaml_end+1):length(source)]
head <- c("<!doctype html>", "<html lang=\"en\">", "<head>",
  "<meta charset=\"utf-8\">",
  "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">",
  "<meta name=\"description\" content=\"Interactive maps and charts of Madrid's 2023 local, regional and national election results by census section.\">",
  "<title>Madrid Elections 2023 — Daniel Almazán</title>",
  "<link rel=\"stylesheet\" href=\"assets/madrid-elections-2023/maplibre-gl.css\">",
  "<link rel=\"stylesheet\" href=\"assets/madrid-elections-2023/article.css?v=20260830-1\">",
  "</head>", "<body>")
writeLines(c(head, body, "</body>", "</html>"), output, useBytes=TRUE)
message("Rendered ", output)
