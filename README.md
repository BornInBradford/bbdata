# About

`bbdata` is an R package developed by Born in Bradford for processing data requests. 

It provides functions for reading user-supplied variables, retrieving variables from Opal, exporting data files, plus some other tools to allow identification of missing variables, slicing of subcohorts etc.

## Installation

To install from Github:
```R
devtools::install_github("BornInBradford/bbdata")
```

## Setup

```R
library(bbdata)
```

To retrieve data from Opal, login credentials must be supplied to the `opalr` package. There are two ways to do this:

1. By directly setting the options in your script such as username/password, personal access token or SSL key pair. See the examples using the `options()` function [here](https://www.obiba.org/opalr/reference/opal.login.html).
2. **Recommended:** Using the `bbdata_creds` option to supply the path to an external and securely managed R script that sets the credentials options that `opalr` needs:

```R
options(bbdata_creds = "path/to/credentials/script")
```

# Reading a request

Three formats are currently supported:

1. **text** A text file with one fully qualified variable name[^1] per line
2. **xlsx** In one of two possible formats
    - **fullnames** An xlsx file with one worksheet where the first column has the column header `variable` and contains a list of fully qualified variable names[^1]
    - **tabular** An xlsx file with one worksheet containing three columns with headers `project`, `table`, and `variable`
3. **manual** A hard coded request, provided as a character vector of fully qualified variable names[^1]

Note that if a wildcard `*` is used in place of the variable name then the full table is requested[^1].

[^1]: A fully qualified variable name is one that specifies the project, table and variable separated by dots, e.g. `project_name.table_name.variable_name`. If a wildcard `*` is used in place of the variable name then the full table is requested, e.g. `project_name.table_name.*`

## Text file request

```R
vars <- bb_opaltxt("path/to/text/file")
```

If the text file contains a header line, this can be skipped as follows:

```R
vars <- bb_opaltxt("path/to/text/file", header = TRUE)
```

## xlsx file request

The `bb_opalxl` function will try to figure out whether the file is in fullnames or tabular format based on the column names.

```R
vars <- bb_opalxl("path/to/xlsx/file")
```

If it cannot work out the format of the file it will exit with an error:

>Format of excel sheet not recognised. Expected either the first column to be called `variable` or to have separate `project`, `table`, `variable` columns.

You can try specifying the format directly:

```R
vars <- bb_opalxl("path/to/xlsx/file", format = "fullnames")
vars <- bb_opalxl("path/to/xlsx/file", format = "tabular")
```

## Manual or hard-coded request

A list of hard-coded variables can be created using the `bb_variables` function, and must then be read in using the `read_bb_opalvars` function:

```R
# using wildcard to return a full table
vars <- bb_variables("DataDictionary.dd_variables.*") |> read_bb_opalvars()

# requesting specific variables from two tables
var_list <- c("BiB_Education_Record.edrecs_y1_phonics.phonics_grade1",
              "BiB_1000.bib1000_6m_main.bib6n01")
vars <- bb_variables(var_list) |> read_bb_opalvars()
```

# Running the query

## Fetching data

Once the Opal variables have been read in, the data can be fetched in one step. For example, if the variables have been read into `vars`:

```R
dat <- fetch_bb_opaldata(vars)

# or

dat <- vars |> fetch_bb_opaldata()
```

Or, from a text format variable request in one step:

```R
dat <- bb_opaltxt("path/to/text/file") |> fetch_bb_opaldata()
```

If you also want to retrieve detailed metadata for the requested variables:

```R
dat <- bb_opaltxt("path/to/text/file") |> fetch_bb_opaldata(meta = TRUE)
```

Note that the default behaviour is not to return detailed metadata as the query can take some time to complete.

## Results

`fetch_bb_opaldata` returns an object called a `bb_opaldata` that is a nested set of named lists containing the data requested and various other pieces of potentially useful information:

| bb_opaldata  |   |
|---|---|
| data | Tibbles containing the data requested, one tibble per Opal table. |
| metadata | If requested using `meta = TRUE` contains two tibbles of metadata. `metadata$variable` contains variable-level metadata and `metadata$table` contains table-level metadata. |
| not_found | A data frame containing the names of variables that were not returned by Opal. |
| request | This is a copy of the original `dd_opalvars` object that was submitted to request the data. |

## Fetching metadata

As we saw [above](#fetching-data), detailed metadata can be returned as part of the bulk Opal query using `fetch_bb_opaldata` by setting `meta = TRUE`. If you **only** require detailed metadata and no tabular data, you might wish to query this from Opal directly:

```R
# fetch variable metadata
vars_info <- bb_opaltxt("path/to/text/file") |> fetch_opal_var_meta()

# fetch table metadata
tabs_info <- bb_opaltxt("path/to/text/file") |> fetch_opal_tab_meta()
```

## Opal session management

By default, `fetch_bb_opaldata` and the metadata fetch functions log into a new Opal session, run the query and then log out cleanly. You can override this behaviour by supplying an active Opal session using the `o` parameter. This allows you to run multiple successive queries in the same Opal session and might be more efficient during complex or lengthy processes:

```R
o <- opalr::opal.login()

dd_request <- bb_variables("DataDictionary.dd_variables.*") |> 
  read_bb_opalvars() |>
  fetch_bb_opaldata(o)

# also works with the metadata fetch functions
vars_info <- bb_opaltxt("path/to/text/file") |> fetch_opal_var_meta(o)
tabs_info <- bb_opaltxt("path/to/text/file") |> fetch_opal_tab_meta(o)

opalr::opal.logout(o)
```


# Interrogating data

## Getting data

The data from each Opal table in the request is in a separate tibble inside the returned `bb_opaldata`. These can be brought forward for further analysis using `get_bb_data`. They can be referred to either by index number or by their full name:

```R
dat <- bb_opaltxt("path/to/text/file") |> fetch_bb_opaldata()

# by index
new_data <- dat |> get_bb_data(1)

# by name
new_data <- dat |> get_bb_data("table_name")
```

Extending the data dictionary example from above:

```R
dat <- bb_variables("DataDictionary.dd_variables.*") |> 
       read_bb_opalvars() |>
       fetch_bb_opaldata()

# get dd_variables data table
vars_info <- dat |> get_bb_data("DataDictionary.dd_variables")
```

## Getting metadata

As we saw [above](#fetching-metadata), detailed variable and table metadata can be queried from Opal directly without returning full tabular data. However, metadata can be requested alongside full tabular data and then brought forward for further analysis as follows:

```R
dat <- bb_variables("DataDictionary.dd_variables.*") |> 
       read_bb_opalvars() |>
       fetch_bb_opaldata(meta = TRUE)

# get variable metadata
vars_info <- dat |> get_bb_var_metadata()

# get table metadata
tabs_info <- dat |> get_bb_tab_metadata()
```

## Checking missing variables

Variables that were not found and therefore not returned by Opal can be retrieved for checking:

```R
not_found <- dat |> get_bb_not_found()
```


# Exporting data

If full flexibility is required, data can be retrieved table by table using `get_bb_data` to allow further processing prior to export as separate or merged files.

For more convenience, `write_bb_data` is provided to automate the process of exporting each tibble in a `bb_opaldata` to a separate file. It also writes csv files containing the names of all variables requested and the names of any variables that were not found. The only required parameter is the path to the desired output folder:

```R
dat |> write_bb_data(path = "path/to/output/folder")
```

By default, `write_bb_data` will prepend each file with 'opaldata' and will export in Stata format. These options can be customised:

```R
# outputs default stata format
# files prepended with 'data_request_name'
dat |> write_bb_data(path = "path/to/output/folder",
                     name = "data_request_name")

# outputs csv format
dat |> write_bb_data(path = "path/to/output/folder",
                     name = "data_request_name",
                     format = "csv")
```

# Fully worked example

Running an example data request, starting from a text format variable list file, checking for missing variables, and exporting to Stata format with customised filenames:

```R
library(bbdata)
options(bbdata_creds = "path/to/credentials/script")

request_id = "1234"
input_file = "path/to/text/file"
output_folder = "path/to/output/folder"

# fetch data
request <- bb_opaltxt(input_file) |> fetch_bb_opaldata()

# check for missing variables
request |> get_bb_not_found()

# export
request |> write_bb_data(path = output_folder, name = request_id)
```

The simple script above can be tailored to run any data request by modifying the parameters `request_id`, `input_file` and `output_folder`. 

If the input format changes, then the `bb_opaltxt` function needs to be changed - see sections on [xlsx](#xlsx-file-request) and [manual](#manual-or-hard-coded-request) formats.

If a different output format is required, then the `format` parameter can be added to `write_bb_data` - see [Exporting data](#exporting-data).
