suppressPackageStartupMessages(library(sf))

root <- getwd()
project <- normalizePath(file.path(root, "source/madrid_elections_2023"), mustWork = TRUE)
public <- file.path(root, "assets/madrid-elections-2023")
prepared <- readRDS(file.path(project, "data/derived/prepared.rds"))

# The article intentionally uses the same canonical 2023 census geometry as
# Madrid Atlas. An alternate checkout can be supplied for portable rebuilds.
atlas_root <- Sys.getenv(
  "MADRID_ATLAS_ROOT",
  file.path(dirname(root), "madrid_map")
)
atlas_geometry <- file.path(atlas_root, "data/processed/sections-2023-thematics.rds")
stopifnot(file.exists(atlas_geometry))
sections <- readRDS(atlas_geometry)
sections <- sections[, c("section_id", "district", "geometry")]
stopifnot(nrow(sections) == 2450, length(unique(sections$section_id)) == 2450)

suffix <- c(local = "local", regional = "assembly", national = "general")
party_properties <- list(
  local = c(pp = "pp", psoe = "psoe", vox = "vox", mas_madrid = "mm"),
  regional = c(pp = "pp", psoe = "psoe", vox = "vox", mas_madrid = "mm", podemos_iu_av = "podemos"),
  national = c(pp = "pp", psoe = "psoe", vox = "vox", sumar = "sumar")
)

for (election in names(suffix)) {
  article <- prepared$article[[election]]
  index <- match(sections$section_id, article$cusec)
  stopifnot(!anyNA(index))
  sections[[paste0("turnout_pct_", suffix[[election]])]] <- article$turnout[index]
  sections[[paste0("leading_party_", suffix[[election]])]] <- article$winner[index]
  for (property in names(party_properties[[election]])) {
    article_column <- party_properties[[election]][[property]]
    sections[[paste0("share_", property, "_", suffix[[election]])]] <- article[[article_column]][index]
  }
}

income_index <- match(sections$section_id, prepared$income$cusec)
stopifnot(!anyNA(income_index))
sections$income_per_household_eur <- round(prepared$income$income[income_index], 2)

tippecanoe <- Sys.which("tippecanoe")
stopifnot(nzchar(tippecanoe))
input <- tempfile(fileext = ".geojson")
on.exit(unlink(input), add = TRUE)
st_write(sections, input, driver = "GeoJSON", delete_dsn = TRUE, quiet = TRUE)
output <- file.path(public, "sections-2023.pmtiles")
status <- system2(tippecanoe, c(
  "-o", output, "--force",
  "--minimum-zoom", "8", "--maximum-zoom", "15",
  "--no-feature-limit", "--no-tile-size-limit",
  "--simplification", "8", "--detect-shared-borders",
  "--coalesce-densest-as-needed",
  "-L", paste0("sections_2023:", input)
))
stopifnot(identical(status, 0L), file.info(output)$size > 0)
message("Built Madrid Atlas-compatible tiles: ", output)
