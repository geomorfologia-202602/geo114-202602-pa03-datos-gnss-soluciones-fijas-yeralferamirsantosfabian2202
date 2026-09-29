pos_read_violin <- function(files,
                            q_filter = NULL,
                            coord_type = c("auto","llh","ecef"),
                            export = c("none","gpkg","kml"),
                            export_path = NULL,
                            export_layer = "pos_points",
                            utm_zone_override = NULL,
                            plot_stat = c("raw","z","absdev"),
                            stat_by = c("archivo","global"),
                            x_label_wrap = 15,
                            x_break_chars = c("-", "_")) {
  coord_type <- match.arg(coord_type)
  export <- match.arg(export)
  plot_stat <- match.arg(plot_stat)
  stat_by <- match.arg(stat_by)
  
  suppressPackageStartupMessages({
    library(stringr); library(dplyr); library(tidyr)
    library(ggplot2); library(sf);     library(purrr)
    library(scales)
  })
  
  # ---------- helper para wrap inteligente en eje X ----------
  smart_wrap_labels <- function(x, width = 15, break_chars = c("-", "_")) {
    if (!is.finite(width) || width <= 0) return(x)
    
    wrap_one <- function(s) {
      if (is.na(s)) return(s)
      chars <- strsplit(s, "", useBytes = TRUE)[[1]]
      n <- length(chars)
      if (n <= width) return(s)
      
      out <- character(0)
      line_start <- 1
      last_pref_break <- NA_integer_
      i <- 1
      
      while (i <= n) {
        ch <- chars[i]
        if (ch %in% break_chars) last_pref_break <- i
        
        # ¿se excedió el ancho?
        if ((i - line_start + 1) > width) {
          if (!is.na(last_pref_break) && last_pref_break >= line_start) {
            # Cortar justo después del separador preferido más cercano
            out <- c(out, paste0(paste(chars[line_start:last_pref_break], collapse = ""), "\n"))
            line_start <- last_pref_break + 1
            last_pref_break <- NA_integer_
            # No avanzamos i aquí: re-evaluamos desde el nuevo inicio de línea
          } else {
            # Sin separador en el tramo: cortar donde toque
            out <- c(out, paste0(paste(chars[line_start:(i-1)], collapse = ""), "\n"))
            line_start <- i
          }
        } else {
          i <- i + 1
        }
      }
      
      out <- c(out, paste(chars[line_start:n], collapse = ""))
      paste(out, collapse = "")
    }
    
    vapply(x, wrap_one, character(1), USE.NAMES = FALSE)
  }
  # -----------------------------------------------------------
  
  rx <- paste0(
    "^\\s*",
    "(\\d{4}/\\d{2}/\\d{2}\\s+\\d{2}:\\d{2}:\\d{2}(?:\\.\\d+)?)",
    "\\s+([+-]?\\d+(?:\\.\\d+)?)",
    "\\s+([+-]?\\d+(?:\\.\\d+)?)",
    "\\s+([+-]?\\d+(?:\\.\\d+)?)",
    "\\s+(\\d+)"
  )
  
  parse_one <- function(f) {
    con <- if (grepl("\\.gz$", f, TRUE)) gzfile(f, "rt") else file(f, "rt")
    on.exit(close(con), add = TRUE)
    lines <- readLines(con, warn = FALSE)
    lines <- lines[!grepl("^\\s*%", lines)]
    lines <- lines[nzchar(trimws(lines))]
    keep <- grepl(rx, lines)
    if (!any(keep)) {
      return(tibble(archivo = basename(f),
                    timestamp = character(0),
                    Lat_o_X = numeric(0),
                    Lon_o_Y = numeric(0),
                    H_o_Z   = numeric(0),
                    Q       = integer(0)))
    }
    m <- stringr::str_match(lines[keep], rx)
    tibble(
      archivo = basename(f),
      timestamp = m[,2],
      Lat_o_X = as.double(m[,3]),
      Lon_o_Y = as.double(m[,4]),
      H_o_Z   = as.double(m[,5]),
      Q       = as.integer(m[,6])
    )
  }
  
  raw_df <- files %>% purrr::map(parse_one) %>% dplyr::bind_rows()
  if (!nrow(raw_df)) return(list(data = tibble(), plot = ggplot() + theme_void()))
  
  if (!is.null(q_filter)) {
    raw_df <- dplyr::filter(raw_df, Q %in% q_filter)
    if (!nrow(raw_df)) return(list(data = tibble(), plot = ggplot() + theme_void()))
  }
  
  detect_type <- function(df) {
    if (coord_type != "auto") return(coord_type)
    llh_ratio <- mean(df$Lat_o_X >= -90 & df$Lat_o_X <= 90 &
                        df$Lon_o_Y >= -180 & df$Lon_o_Y <= 180, na.rm = TRUE)
    if (is.na(llh_ratio)) "llh" else if (llh_ratio > 0.9) "llh" else "ecef"
  }
  inferred_type <- detect_type(raw_df)
  
  if (inferred_type == "llh") {
    llh_df <- transmute(raw_df, archivo, timestamp,
                        lat = Lat_o_X, lon = Lon_o_Y, h = H_o_Z, Q)
    g_llh <- sf::st_as_sf(llh_df, coords = c("lon","lat"), crs = 4326, remove = FALSE)
    g_llh$height_m <- llh_df$h
  } else {
    g_ecef <- sf::st_as_sf(transmute(raw_df, archivo, timestamp,
                                     X = Lat_o_X, Y = Lon_o_Y, Z = H_o_Z, Q),
                           coords = c("X","Y","Z"), crs = 4978, remove = FALSE)
    g_llh3d <- sf::st_transform(g_ecef, 4326)
    coords <- do.call(rbind, sf::st_coordinates(g_llh3d))
    llh_df <- sf::st_drop_geometry(g_llh3d) |>
      mutate(lon = coords[,1], lat = coords[,2], h = coords[,3])
    g_llh <- sf::st_as_sf(llh_df, coords = c("lon","lat"), crs = 4326, remove = FALSE)
    g_llh$height_m <- llh_df$h
  }
  
  mean_lon <- mean(g_llh$lon, na.rm = TRUE)
  mean_lat <- mean(g_llh$lat, na.rm = TRUE)
  utm_zone <- if (is.null(utm_zone_override)) {
    z <- floor((mean_lon + 180)/6) + 1; max(1, min(60, z))
  } else utm_zone_override
  hemi_north <- mean_lat >= 0
  utm_epsg <- if (hemi_north) 32600 + utm_zone else 32700 + utm_zone
  
  g_utm <- sf::st_transform(g_llh, utm_epsg)
  en <- sf::st_coordinates(g_utm)
  
  g_all <- sf::st_drop_geometry(g_llh) |>
    mutate(E = en[,1], N = en[,2],
           utm_zone = utm_zone,
           hemisphere = ifelse(hemi_north, "N", "S"),
           coord_source = inferred_type) |>
    left_join(raw_df %>% select(archivo, timestamp, Lat_o_X, Lon_o_Y, H_o_Z),
              by = c("archivo","timestamp"))
  
  data_out <- g_all %>%
    select(archivo, timestamp, Q,
           lat, lon, height_m,
           E, N, utm_zone, hemisphere,
           Lat_o_X, Lon_o_Y, H_o_Z, coord_source)
  
  # Datos para el plot
  df_plot <- data_out %>%
    transmute(archivo,
              Easting_m = E, Northing_m = N, Height_m = height_m) %>%
    pivot_longer(c(Easting_m, Northing_m, Height_m),
                 names_to = "Componente", values_to = "Valor")
  
  # Transformación opcional
  if (plot_stat != "raw") {
    grp <- if (stat_by == "archivo") c("archivo","Componente") else "Componente"
    df_plot <- df_plot %>%
      group_by(across(all_of(grp))) %>%
      mutate(
        mean_val = mean(Valor, na.rm = TRUE),
        sd_val   = sd(Valor, na.rm = TRUE),
        Valor = dplyr::case_when(
          plot_stat == "z"      ~ ifelse(sd_val > 0, (Valor - mean_val)/sd_val, 0),
          plot_stat == "absdev" ~ abs(Valor - mean_val),
          TRUE ~ Valor
        )
      ) %>%
      ungroup() %>%
      select(-mean_val, -sd_val)
  }
  
  y_lab <- dplyr::case_when(
    plot_stat == "raw"    ~ "Magnitud (m)",
    plot_stat == "z"      ~ "Z-score (adimensional)",
    plot_stat == "absdev" ~ "Desv. absoluta respecto de la media (m)"
  )
  y_fmt <- if (plot_stat == "z") scales::label_number(accuracy = 0.01) else scales::label_number(accuracy = 0.001)
  sub_stat <- dplyr::case_when(
    plot_stat == "raw"    ~ "Valores brutos",
    plot_stat == "z"      ~ paste0("Z-score · agrupación: ", stat_by),
    plot_stat == "absdev" ~ paste0("|x-µ| · agrupación: ", stat_by)
  )
  
  p <- ggplot(df_plot, aes(x = archivo, y = Valor, fill = archivo)) +
    geom_violin(trim = FALSE, alpha = 0.85) +
    geom_point(position = position_jitter(width = 0.1, height = 0),
               alpha = 0.55, size = 1) +
    facet_wrap(~ Componente, nrow = 1, ncol = 3, scales = "free_y") +
    scale_y_continuous(labels = y_fmt) +
    scale_x_discrete(labels = function(x) smart_wrap_labels(x, width = x_label_wrap, break_chars = x_break_chars)) +
    labs(x = "Archivo (.pos)", y = y_lab,
         title = "Distribución por componente en UTM (WGS84)",
         subtitle = paste0(
           sub_stat, " · Zona UTM ", utm_zone, " (", ifelse(hemi_north,"N","S"), ")",
           " · Tipo detectado: ", inferred_type,
           if (!is.null(q_filter))
             paste0(" · Filtro Q ∈ {", paste(sort(unique(q_filter)), collapse=","), "}")
           else ""
         )) +
    theme_minimal() +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1),
      axis.text.y = element_text(angle = 45, hjust = 1),
      strip.text  = element_text(face = "bold"),
      legend.position = "none"
    )
  
  export_file <- NULL
  if (export != "none") {
    if (is.null(export_path)) {
      export_path <- if (export == "gpkg") "pos_converted.gpkg" else "pos_converted.kml"
    }
    g_export <- sf::st_as_sf(data_out, coords = c("lon","lat"), crs = 4326, remove = FALSE)
    if (export == "gpkg") {
      sf::st_write(g_export, export_path, layer = export_layer, delete_layer = TRUE, quiet = TRUE)
    } else {
      sf::st_write(g_export, export_path, delete_dsn = TRUE, quiet = TRUE)
    }
    export_file <- normalizePath(export_path, winslash = "/", mustWork = FALSE)
  }
  
  list(
    data = data_out,
    plot = p,
    utm_epsg = utm_epsg,
    utm_zone = utm_zone,
    hemisphere = ifelse(hemi_north,"N","S"),
    coord_source = inferred_type,
    export = export_file
  )
}
