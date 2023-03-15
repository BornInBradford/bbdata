# About bbdata

`bbdata` is an R package developed by Born in Bradford for processing data requests. 

It provides functions for reading user-supplied variables, retrieving variables from Opal, exporting data files, plus some other tools to allow identification of missing variables, slicing of subcohorts etc.

## Installation

To install from Github:
```R
devtools::install_github("BornInBradford/bbdata")

library(bbdata)
```

# Reading a request

Three formats are currently supported:

1. **text** A text file with one fully qualified variable name[^1] per line
2. **xlsx** In one of two possible formats
    - **fullnames** An xlsx file with one worksheet where the first column has the column header `variable` and contains a list of fully qualified variable names[^1]
    - **tabluar** An xlsx file with one worksheet containing three columns with headers `project`, `table`, and `variable`
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

# Fetching data

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

# Interrogating data




# Exporting data





# Fully worked example



