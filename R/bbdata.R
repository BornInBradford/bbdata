
bb_opal_login <- function(credentials = "H:/MyDocuments/R/opal_opts.R") {
  
  source(credentials)
  
  o <- opalr::opal.login()
  
  return(o)
  
}

bb_opal_logout <- function(o) {
  
  opalr::opal.logout(o)
  
}

#' @export
bb_variables <- function(full_name = character(0)) {
  
  me <- list(variables = full_name)
  
  class(me) <- "bb_variables"
  
  return(me)
  
}


bb_cohort <- function(x, ...) {
  
  UseMethod("bb_cohort", x)
  
}


#' @export
bb_cohort.character <- function(id_list) {
  
  me <- list(cohort = tibble::tibble(id = id_list))
  
  class(me) <- "bb_cohort"
  
  return(me)
  
}


#' @export
bb_cohort.bb_opalvars <- function(opalvars, o = NULL, logout = is.null(o$sid)) {
  
  table_ids <- list()
  
  if(is.null(o$sid)) o <- bb_opal_login()
  
  tables <- get_bb_tables(opalvars)
  
  for(t in tables) {
    
    message(paste0("Checking entities in ", t))
    
    opalr::opal.assign.table.tibble(o, 
                                    symbol = "dat", 
                                    value = t,
                                    variables = list("id"))
    
    get_ids <- opalr::opal.execute(o, "dat$id")
    
    table_ids <- append(table_ids, list(get_ids))
    
  }
  
  if(logout) bb_opal_logout(o)
  
  common_ids <- Reduce(intersect, table_ids) |> as.character()
  
  message(paste0(length(common_ids), " common ids found"))
  
  me <- list(cohort = tibble::tibble(id = common_ids))
  
  class(me) <- "bb_cohort"
  
  return(me)
  
}


#' @export
bb_opaltxt <- function(filename = character(0), header = FALSE) {
  
  vars <- read.table(filename, header = header)
  
  vars <- trimws(vars[[1]])
  
  varlist <- bb_variables(vars)
  
  me <- read_bb_opalvars(varlist)
  
  return(me)
  
}


#' @export
bb_opalxl <- function(filename = character(0), sheet = 1, format = "notfound") {
  
  vars <- readxl::read_excel(filename, sheet)
  
  if(format == "notfound") {
    
    if(tolower(names(vars)[1]) == "variable") format = "fullnames"
    if(all(tolower(names(vars)[1:3]) == c("project", "table", "variable"))) format = "tabular"
    
  }
  
  if(format == "notfound") stop("Format of excel sheet not recognised. Expected either the first column to be called `variable` or to have separate `project`, `table`, `variable` columns.")
  
  if(format == "fullnames") {
    
    vars <- trimws(vars[[1]])
    
  }
  
  if(format == "tabular") {
    
    vars$vars <- paste0(trimws(vars$project), ".", trimws(vars$table), ".", trimws(vars$variable))
    
    vars <- vars$vars
    
  }
  
  varlist <- bb_variables(vars)
  
  me <- read_bb_opalvars(varlist)
  
  return(me)
  
}


#' @export
bb_cohorttxt <- function(filename = character(0)) {
  
  id_list <- read.csv(filename)
  
  me <- bb_cohort(id_list[[1]])
  
  return(me)
  
}


read_bb_opalvars <- function(x) {
  
  UseMethod("read_bb_opalvars", x)
  
}


#' @export
read_bb_opalvars.bb_variables <- function(varlist) {
  
  vars_df <- data.frame(varfullname = varlist$variables)
  vars_df <- tidyr::separate(vars_df, varfullname, c("project", "table", "variable"), sep = "\\.")
  vars_df <- dplyr::mutate(vars_df, proj_table = paste(project, table, sep = "."))
  
  projects <- unique(vars_df$project)
  tables <- unique(vars_df$proj_table)
  
  me <- list(vars_requested = varlist,
             projects = projects,
             tables = tables,
             vars_df = vars_df)
  
  class(me) <- "bb_opalvars"
  
  return(me)
  
}


fetch_bb_opaldata <- function(x, ...) {
  
  UseMethod("fetch_bb_opaldata", x)
  
}


#' @export
fetch_bb_opaldata.bb_opalvars <- function(opalvars, o = NULL, logout = is.null(o$sid), meta = FALSE) {
  
  me <- list(data = list(),
             metadata = list(),
             not_found = data.frame(missing_var = character(0)),
             request = opalvars)
  
  if(is.null(o$sid)) o <- bb_opal_login()
  
  tables <- get_bb_tables(opalvars)
  vars_df <- get_bb_vars_df(opalvars)
  
  for(t in tables) {
    
    message(paste0("Fetching ", t))
    
    opalr::opal.assign.table.tibble(o, 
                                    symbol = "dat", 
                                    value = t)
    
    tbl_vars <- subset(x = vars_df,
                       subset = proj_table == t,
                       select = variable)
    
    tbl_vars <- tbl_vars$variable
    
    r_select_vars <- paste0("select_vars <- c('id', ", paste0("'", tbl_vars, "'", collapse = ", "), ")")
    
    r_missing_vars <- "missing_vars <- setdiff(select_vars, names(dat))"
    
    r_clean_vars <- "select_vars <- intersect(select_vars, names(dat))"
    
    r_subset <- paste0("dat <- dat[select_vars]")
    
    opalr::opal.execute(o, script = r_select_vars)
    opalr::opal.execute(o, script = r_missing_vars)
    opalr::opal.execute(o, script = r_clean_vars)
    
    if(!"*" %in% tbl_vars) opalr::opal.execute(o, script = r_subset)
    
    dat <- opalr::opal.execute(o, script = "dat")
    nf <- opalr::opal.execute(o, script = "missing_vars")
    
    nf <- nf[!nf == "*"]
    
    me$data <- append(me$data, list(dat))
    if(length(nf) > 0) {
      nf <- paste0(t, ".", nf)
      me$not_found <- rbind(me$not_found, data.frame(missing_vars = nf))
    }
    
  }
  
  names(me$data) <- tables
  
  if(meta) {
    
    message("Fetching Opal variable metadata")
    me$metadata$variable <- fetch_opal_var_meta(opalvars, o)
    
    message("Fetching Opal table metadata")
    me$metadata$table <- fetch_opal_tab_meta(opalvars, o)
    
  }
  
  if(logout) bb_opal_logout(o)

  class(me) <- "bb_opaldata"
  
  return(me)
  
}


#' @export
fetch_opal_var_meta <- function(opalvars, o = NULL, logout = is.null(o$sid)) {
  
  tables <- opalvars |> get_bb_tables()
  
  variables <- tibble::tibble()
  
  if(is.null(o$sid)) o <- bb_opal_login()
  
  for(t in tables) {
    
    message(paste0("Retrieving variable annotations for ", t))
    
    proj_name <- strsplit(t, "\\.")[[1]][1]
    tab_name <- strsplit(t, "\\.")[[1]][2]
    
    v <- opalr::opal.variables(o, proj_name, tab_name)
    
    if(nrow(v) > 0) {
      variables <- variables |> dplyr::bind_rows(v)
    }
    
  }
  
  variables <- variables |> 
    dplyr::mutate(variable_id = paste0(datasource, ".", table, ".", name)) |>
    dplyr::relocate(variable_id)
  
  vars_select <- opalvars |> get_bb_vars_requested()
  
  variables <- variables |> dplyr::filter(variable_id %in% vars_select)
  
  if(logout) bb_opal_logout(o)
  
  return(variables)
  
}


#' @export
fetch_opal_tab_meta <- function(opalvars, o = NULL, logout = is.null(o$sid)) {
  
  projects <- opalvars |> get_bb_projects()
  
  tables <- tibble::tibble()
  
  if(is.null(o$sid)) o <- bb_opal_login()
  
  for(p in projects) {
    
    message(paste0("Retrieving table annotations for ", p))

    t <- opalr::opal.tables(o, p, counts = TRUE)
    
    if(nrow(t) > 0) {
      tables <- tables |> dplyr::bind_rows(t)
    }
    
  }
  
  tables <- tables |>
    dplyr::mutate(table_id = paste0(datasource, ".", name)) |>
    dplyr::relocate(table_id)

  tabs_select <- opalvars |> get_bb_tables()

  tables <- tables |> dplyr::filter(table_id %in% tabs_select)
  
  tabs_dd <- bb_variables("DataDictionary.dd_tables.*") |> 
    read_bb_opalvars() |>
    fetch_bb_opaldata() |>
    get_bb_data("DataDictionary.dd_tables") |>
    dplyr::select(id, long_name, description)
  
  tables <- tables |> dplyr::left_join(tabs_dd, by = c("table_id" = "id"))
  
  if(logout) bb_opal_logout(o)
  
  return(tables)
  
}


get_bb_projects <- function(x, ...) {
  
  UseMethod("get_bb_projects", x)
  
}


#' @export
get_bb_projects.bb_opalvars <- function(opalvars) {
  
  projects <- opalvars$projects
  
  return(projects)
  
}


get_bb_tables <- function(x, ...) {
  
  UseMethod("get_bb_tables", x)
  
}


#' @export
get_bb_tables.bb_opalvars <- function(opalvars) {

  tables <- opalvars$tables
  
  return(tables)
  
}


get_bb_vars_requested <- function(x, ...) {
  
  UseMethod("get_bb_vars_requested", x)
  
}


#' @export
get_bb_vars_requested.bb_opalvars <- function(opalvars) {
  
  vars <- opalvars$vars_requested$variables
  
  return(vars)
  
}


get_bb_vars_df <- function(x, ...) {
  
  UseMethod("get_bb_vars_df", x)
  
}


#' @export
get_bb_vars_df.bb_opalvars <- function(opalvars) {
  
  vars_df <- opalvars$vars_df
  
  return(vars_df)
  
}


get_bb_data <- function(x, ...) {
  
  UseMethod("get_bb_data", x)
  
}


#' @export
get_bb_data.bb_opaldata <- function(opaldata, df_name = character(0), df_index = integer(0)) {
  
  if(length(df_name) == 1) dat <- opaldata$data[[df_name]]
  
  if(length(df_index) == 1) dat <- opaldata$data[[df_index]]
  
  return(dat)
  
}


#' @export
get_bb_data.bb_cohort <- function(cohort) {
  
  dat <- cohort$cohort
  
  dat$id <- as.character(dat$id)
  
  return(dat)
  
  
}


get_bb_var_metadata <- function(x) {
  
  UseMethod("get_bb_var_metadata", x)
  
}


#' @export
get_bb_var_metadata.bb_opaldata <- function(opaldata) {
  
  dat <- opaldata$metadata$variable
  
  return(dat)
  
}


get_bb_tab_metadata <- function(x) {
  
  UseMethod("get_bb_tab_metadata", x)
  
}


#' @export
get_bb_tab_metadata.bb_opaldata <- function(opaldata) {
  
  dat <- opaldata$metadata$table
  
  return(dat)
  
}


write_bb_data <- function(x, ...) {
  
  UseMethod("write_bb_data", x)
  
}


#' @export
write_bb_data.bb_opaldata <- function(opaldata, 
                                      path,
                                      name = "opaldata",
                                      format = "stata") {
  
  for(d in 1:length(opaldata$data)) {
    
    message(paste0("Writing ", names(opaldata$data)[d]))
    
    if(format == "stata") {
      
      filename <- file.path(path, paste0(name, "_", names(opaldata$data)[d], ".dta"))
      
      haven::write_dta(data = get_bb_data(opaldata, df_index = d),
                       path = filename)
      
    }
    
    if(format == "csv") {
      
      filename <- file.path(path, paste0(name, "_", names(opaldata$data)[d], ".csv"))
      
      readr::write_csv(x = get_bb_data(opaldata, df_index = d),
                       file = filename,
                       na = "")
      
    }
    
  }
  
  if(nrow(opaldata$not_found) > 0) {
    
    filename <- file.path(path, paste0(name, "_opal_vars_not_found.csv"))
    
    readr::write_csv(x = opaldata$not_found,
                     file = filename,
                     na = "")
    
    
  }
  
  if(length(opaldata$request$vars_requested$variables) > 0) {
    
    filename <- file.path(path, paste0(name, "_opal_vars_requested.csv"))
    
    vars <- data.frame(variable = opaldata$request$vars_requested$variables)
    
    readr::write_csv(x = vars,
                     file = filename,
                     na = "")
    
    
  }
  
}


subset_bb_data <- function(x, ...) {
  
  UseMethod("subset_bb_data", x)
  
}


#' @export
subset_bb_data.bb_opaldata <- function(opaldata, cohort, df_name = character(0)) {
  
  for(d in 1:length(opaldata$data)) {
    
    if(length(df_name) == 0 || names(opaldata$data)[d] %in% df_name) {
      
      subset_df <- dplyr::inner_join(get_bb_data(cohort), get_bb_data(opaldata, df_index = d))
      
      opaldata$data[d] <- list(subset_df)
      
    }
    
  }
  
  return(opaldata)
  
}



