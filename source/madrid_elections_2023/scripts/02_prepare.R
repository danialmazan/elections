suppressPackageStartupMessages({library(readxl); library(sf); library(jsonlite)})
options(stringsAsFactors = FALSE)
project <- normalizePath(file.path(getwd(), "source/madrid_elections_2023"), mustWork = TRUE)
raw_dir <- file.path(project, "data/raw")
derived <- file.path(project, "data/derived")
public <- file.path(getwd(), "assets/madrid-elections-2023")
dir.create(derived, recursive = TRUE, showWarnings = FALSE)
dir.create(public, recursive = TRUE, showWarnings = FALSE)

read_madrid <- function(path, election) {
  x <- read_excel(path, col_names = FALSE)
  party_codes <- trimws(as.character(unlist(x[7, 12:ncol(x)])))
  party_codes <- party_codes[!is.na(party_codes) & nzchar(party_codes)]
  d <- x[12:nrow(x), seq_len(11 + length(party_codes))]
  names(d) <- c("district", "neighbourhood", "section", "mesa", "census", "abstention",
                "cast", "null", "valid", "blank", "candidate_total", party_codes)
  d <- d[!is.na(d$district) & !is.na(d$section) & !is.na(d$mesa), ]
  numeric_cols <- setdiff(names(d), "mesa")
  for (nm in numeric_cols) d[[nm]] <- suppressWarnings(as.numeric(d[[nm]]))
  d$cusec <- sprintf("28079%02d%03d", d$district, d$section)
  parties <- party_codes
  agg_names <- c("census", "cast", "null", "valid", "blank", "candidate_total", parties)
  a <- aggregate(d[agg_names], list(cusec = d$cusec, district = d$district), sum, na.rm = TRUE)
  a$election <- election
  a$turnout <- 100 * a$cast / a$census
  winner_i <- max.col(as.matrix(a[parties]), ties.method = "first")
  a$winner_raw <- parties[winner_i]
  a
}

read_ministry <- function(path, election, stamp) {
  meta_widths <- c(2,4,2,1,2,2,3,2,3,1,1,7,7,7,7,7,7,7,7,7,7,7,1)
  meta_names <- c("election_code","year","month","run","ccaa","province","local","district",
                  "section","empty","mesa","ine_census","census","cere_census","votes_cere",
                  "votes_1st","votes_2nd","blank","null","candidate_total","yes","no","official")
  meta <- read.fwf(unz(path, paste0("09", stamp, ".DAT")), widths=meta_widths,
                   col.names=meta_names, stringsAsFactors=FALSE)
  meta <- meta[meta$province==28 & meta$local==79,]
  meta$cusec <- sprintf("28079%02d%03d", meta$district, meta$section)
  meta$cast <- meta$candidate_total + meta$blank + meta$null
  meta$valid <- meta$candidate_total + meta$blank
  base_names <- c("census","cast","null","valid","blank","candidate_total")
  base <- aggregate(meta[base_names], list(cusec=meta$cusec, district=meta$district), sum, na.rm=TRUE)

  vote_widths <- c(2,4,2,1,2,2,3,2,3,1,1,6,7)
  vote_names <- c("election_code","year","month","run","ccaa","province","local","district",
                  "section","empty","mesa","candidate","votes")
  votes <- read.fwf(unz(path, paste0("10", stamp, ".DAT")), widths=vote_widths,
                    col.names=vote_names, stringsAsFactors=FALSE)
  votes <- votes[votes$province==28 & votes$local==79,]
  votes$cusec <- sprintf("28079%02d%03d", votes$district, votes$section)
  vote_section <- aggregate(votes$votes, list(cusec=votes$cusec, candidate=votes$candidate), sum)
  names(vote_section)[3] <- "votes"
  wide <- reshape(vote_section, idvar="cusec", timevar="candidate", direction="wide")

  # Candidate labels are Latin-1 fixed-width bytes. POSIX byte slicing avoids
  # altering field widths before the labels are converted to UTF-8.
  cmd <- sprintf("unzip -p %s %s | cut -b 9-64 | iconv -f ISO-8859-1 -t UTF-8",
                 shQuote(path), shQuote(paste0("03", stamp, ".DAT")))
  lines <- readLines(pipe(cmd), warn=FALSE)
  labels <- data.frame(candidate=as.numeric(substr(lines,1,6)), short=trimws(substr(lines,7,56)))
  city_totals <- aggregate(votes~candidate, votes, sum)
  city_totals <- merge(city_totals, labels, by="candidate", all.x=TRUE)
  city_totals <- city_totals[city_totals$votes > 0,]
  city_totals <- city_totals[order(-city_totals$votes, city_totals$candidate),]
  candidate_cols <- paste0("votes.", city_totals$candidate)
  candidate_cols <- candidate_cols[candidate_cols %in% names(wide)]
  matrix_votes <- as.matrix(wide[candidate_cols]); matrix_votes[is.na(matrix_votes)] <- 0
  short_lookup <- setNames(city_totals$short, city_totals$candidate)

  a <- merge(base, wide, by="cusec", all.x=TRUE, sort=FALSE)
  a$election <- election
  a$turnout <- 100*a$cast/a$census
  # Recalculate winners after merge so the code follows the base section order.
  wm <- as.matrix(a[candidate_cols]); wm[is.na(wm)] <- 0
  winner_codes <- as.numeric(sub("votes\\.", "", candidate_cols[max.col(wm, ties.method="first")]))
  a$winner_raw <- unname(short_lookup[as.character(winner_codes)])
  for (i in seq_len(nrow(city_totals))) {
    nm <- city_totals$short[i]
    col <- paste0("votes.", city_totals$candidate[i])
    if (!is.na(nm) && nzchar(nm) && col %in% names(a)) a[[nm]] <- a[[col]]
  }
  a
}

elections <- list(
  local=read_ministry(file.path(raw_dir,"ministry_local.zip"), "local", "042305"),
  regional=read_madrid(file.path(raw_dir,"regional.xlsx"), "regional"),
  national=read_ministry(file.path(raw_dir,"ministry_national.zip"), "national", "022307")
)

party_map <- list(
  local = c(PP="PP", MM="MM-VQ", PSOE="PSOE", VOX="VOX"),
  regional = c(PP="PP", MM="MM-VQ", PSOE="PSOE", VOX="VOX", PODEMOS="PODEMOS-IU-AV"),
  national = c(PP="PP", PSOE="PSOE", SUMAR="SUMAR", VOX="VOX")
)
winner_map <- c("PP"="PP", "PSOE"="PSOE", "MM-VQ"="MM", "SUMAR"="SUMAR")

income_parts <- lapply(c(0,1000,2000), function(i) st_read(file.path(raw_dir, sprintf("income_%04d.geojson", i)), quiet=TRUE))
income <- do.call(rbind, income_parts)
stopifnot(nrow(income) == 2450, length(unique(income$CUSEC)) == 2450)
income$income <- suppressWarnings(as.numeric(income$dato2))
income$income_note <- ifelse(is.na(income$income), income$nota2, NA_character_)
income <- income[, c("CUSEC", "CDIS", "income", "income_note")]
names(income)[1] <- "cusec"
income <- st_make_valid(income)
income <- st_transform(income, 4326)
income <- st_simplify(income, dTolerance = 0.00006, preserveTopology = TRUE)

all_data <- list()
summary_rows <- list()
curve_rows <- list()
for (e in names(elections)) {
  a <- elections[[e]]
  m <- match(income$cusec, a$cusec)
  stopifnot(!anyNA(m))
  pmap <- party_map[[e]]
  out <- data.frame(cusec = income$cusec, district = a$district[m], census = a$census[m],
                    valid = a$valid[m], turnout = round(a$turnout[m], 2),
                    winner = unname(winner_map[a$winner_raw[m]]), stringsAsFactors = FALSE)
  for (key in names(pmap)) out[[tolower(key)]] <- round(100 * a[[pmap[[key]]]][m] / a$valid[m], 2)
  all_data[[e]] <- out
  for (key in names(pmap)) {
    votes <- sum(a[[pmap[[key]]]])
    summary_rows[[length(summary_rows)+1]] <- data.frame(election=e, party=key, votes=votes,
      share=100*votes/sum(a$valid), turnout=100*sum(a$cast)/sum(a$census), sections=sum(out$winner==key, na.rm=TRUE))
    vars <- list(turnout=list(x=out$turnout, y=out[[tolower(key)]]),
                 income=list(x=income$income, y=out[[tolower(key)]]))
    for (chart in names(vars)) {
      keep <- is.finite(vars[[chart]]$x) & is.finite(vars[[chart]]$y)
      fit <- loess(vars[[chart]]$y[keep] ~ vars[[chart]]$x[keep], span=.5, degree=2,
                   control=loess.control(surface="direct"))
      gx <- seq(min(vars[[chart]]$x[keep]), max(vars[[chart]]$x[keep]), length.out=80)
      curve_rows[[length(curve_rows)+1]] <- data.frame(election=e, party=key, chart=chart,
        x=round(gx,2), y=round(predict(fit, gx),2))
    }
  }
  # Turnout-income curve does not depend on party, but remains election-specific.
  keep <- is.finite(income$income) & is.finite(out$turnout)
  fit <- loess(out$turnout[keep] ~ income$income[keep], span=.5, degree=2,
               control=loess.control(surface="direct"))
  gx <- seq(min(income$income[keep]), max(income$income[keep]), length.out=80)
  curve_rows[[length(curve_rows)+1]] <- data.frame(election=e, party="ALL", chart="turnout_income",
    x=round(gx,2), y=round(predict(fit,gx),2))
}

summary <- do.call(rbind, summary_rows)
curves <- do.call(rbind, curve_rows)

# Compact feature properties and coordinates. Election arrays use the same feature order.
geom <- income[, c("cusec", "CDIS", "income")]
names(geom)[2] <- "district"
geom$income <- ifelse(is.na(geom$income), NA, round(geom$income))
st_write(geom, file.path(public, "sections.geojson"), driver="GeoJSON", delete_dsn=TRUE,
         layer_options="COORDINATE_PRECISION=5", quiet=TRUE)
write_json(list(elections=all_data, summary=summary, curves=curves),
           file.path(public, "data.json"), dataframe="rows", na="null", auto_unbox=TRUE, digits=NA)

saveRDS(list(elections=elections, article=all_data, income=income, summary=summary, curves=curves),
        file.path(derived, "prepared.rds"))
write.csv(summary, file.path(derived, "city_summary.csv"), row.names=FALSE)
message("Prepared public assets: ", public)
