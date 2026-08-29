options(timeout = 300)
root <- normalizePath(file.path(dirname(commandArgs(trailingOnly = FALSE)[grep("--file=", commandArgs(trailingOnly = FALSE))]), ".."), mustWork = FALSE)
root <- normalizePath(file.path(getwd(), "source/madrid_elections_2023"), mustWork = FALSE)
raw <- file.path(root, "data/raw")
dir.create(raw, recursive = TRUE, showWarnings = FALSE)

download <- function(url, dest) {
  if (!file.exists(dest) || file.info(dest)$size == 0) {
    message("Downloading ", basename(dest))
    download.file(url, dest, mode = "wb", quiet = FALSE)
  }
}

# Stable direct files discovered from the publishers' dataset pages.
download("https://datos.madrid.es/dataset/210285-0-elecciones-ayuntamiento-madrid/resource/210285-1-elecciones-ayuntamiento-madrid-xlsx/download/210285-1-elecciones-ayuntamiento-madrid-xlsx.xlsx",
         file.path(raw, "local.xlsx"))
download("https://www.madrid.es/UnidadesDescentralizadas/UDCEstadistica/Nuevaweb/Elecciones%20y%20Participaci%C3%B3n%20Ciudadana/Elecciones/Resultados%20electorales/Asamblea/Asamblea%202023/Mesas/G1240123.xlsx",
         file.path(raw, "regional.xlsx"))
download("https://www.madrid.es/UnidadesDescentralizadas/UDCEstadistica/Nuevaweb/Elecciones%20y%20Participaci%C3%B3n%20Ciudadana/Elecciones/Resultados%20electorales/Congreso/Congreso%202023/Mesas/G1340123_prov.xlsx",
         file.path(raw, "national.xlsx"))
download("https://infoelectoral.interior.gob.es/estaticos/docxl/apliextr/04202305_MESA.zip",
         file.path(raw, "ministry_local.zip"))
download("https://infoelectoral.interior.gob.es/estaticos/docxl/apliextr/02202307_MESA.zip",
         file.path(raw, "ministry_national.zip"))

base <- "https://www.ine.es/servergis/rest/services/ws/ADRH_2023_Renta_media_por_hogar/MapServer/3/query"
for (offset in c(0, 1000, 2000)) {
  query <- paste0(base,
    "?where=CUMUN%3D%2728079%27&outFields=*&returnGeometry=true&outSR=4326",
    "&resultOffset=", offset, "&resultRecordCount=1000&f=geojson")
  download(query, file.path(raw, sprintf("income_%04d.geojson", offset)))
}

manifest <- read.csv(file.path(root, "config/sources.csv"), check.names = FALSE)
paths <- c("local.xlsx", "regional.xlsx", "national.xlsx", "ministry_local.zip",
           "ministry_national.zip", "income_0000.geojson", "income_1000.geojson",
           "income_2000.geojson")
checksum_line <- function(path) {
  out <- system2("shasum", c("-a", "256", shQuote(path)), stdout=TRUE)
  strsplit(out, "[[:space:]]+")[[1]][1]
}
checksums <- vapply(file.path(raw, paths), checksum_line, "")
write.csv(data.frame(file = paths, sha256 = unname(checksums)),
          file.path(root, "config/checksums.csv"), row.names = FALSE)
message("Raw inputs and checksums ready in ", raw)
