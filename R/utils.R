
#' Melt multiple sets of columns in parallel
#'
#' Essentially this is a wrapper around [gather][tidyr::gather] that
#' is able to [bind_cols][dplyr::bind_cols] with several gather operations. This is useful when a wide
#' data frame contains uncertainty or flag information in paired columns.
#'
#' @param x A data.frame
#' @param key Column name to use to store variables, which are the column names
#'   of the first gather operation.
#' @param ... Named arguments in the form `new_col_name = c(old, col, names)`. All
#'   named arguments must have the same length (i.e., gather the same number of columns).
#' @param convert Convert types (see [gather][tidyr::gather])
#' @param factor_key Control whether the key column is a factor or character vector.
#'
#' @seealso [gather][tidyr::gather]
#' @return A gathered data frame.
#' @export
#'
#' @examples
#' # gather paired value/error columns using
#' # parallel_gather
#' parallel_gather(pocmajsum,
#'   key = "param",
#'   value = c(Ca, Ti, V),
#'   sd = c(Ca_sd, Ti_sd, V_sd)
#' )
#'
#' # identical result using only tidyverse functions
#' library(dplyr)
#' library(tidyr)
#' gathered_values <- pocmajsum %>%
#'   select(core, depth, Ca, Ti, V) %>%
#'   gather(Ca, Ti, V,
#'     key = "param", value = "value"
#'   )
#' gathered_sds <- pocmajsum %>%
#'   select(core, depth, Ca_sd, Ti_sd, V_sd) %>%
#'   gather(Ca_sd, Ti_sd, V_sd,
#'     key = "param_sd", value = "sd"
#'   )
#'
#' bind_cols(
#'   gathered_values,
#'   gathered_sds %>% select(sd)
#' )
#'
parallel_gather <- function(x, key, ..., convert = FALSE, factor_key = FALSE) {
  # enquos arguments
  lst <- quos(...)

  # check arguments
  if (length(lst) == 0) {
    abort("Must pass at least one value = columns in parallel_gather()")
  }

  if (is.null(names(lst)) || any(names(lst) == "")) {
    abort("All arguments to parallel_gather() must be named")
  }

  # use a hack to get column names as character using tidyeval and dplyr
  lst_as_colnames <- lapply(lst, function(name_quo) {
    tidyselect::vars_select(colnames(x), !!name_quo)
  })

  # pass to parallel gather base
  parallel_gather_base(x, key, lst_as_colnames, convert = convert, factor_key = factor_key)
}

parallel_gather_base <- function(x, key, lst_as_colnames, convert = FALSE, factor_key = FALSE) {
  # check arguments
  if (length(lst_as_colnames) == 0) {
    abort("Must pass at least one value = columns in parallel_gather()")
  }

  if (is.null(names(lst_as_colnames)) || any(names(lst_as_colnames) == "")) {
    abort("All arguments to parallel_gather() must be named")
  }

  # check length (each argument should refer to the same number of columns)
  arg_col_count <- vapply(lst_as_colnames, length, integer(1))
  if (!length(unique(arg_col_count)) == 1) {
    abort("All named arguments must refer to the same number of columns")
  }

  # id variables are those not mentioned in ...
  id_vars <- setdiff(colnames(x), unlist(lst_as_colnames))

  # do gather for each item in ..., using id_vars and cols mentioned in
  # each argument
  gathered <- lapply(seq_along(lst_as_colnames), function(i) {
    tidyr::gather(x[c(id_vars, lst_as_colnames[[i]])],
      key = !!key, value = !!(names(lst_as_colnames)[i]),
      !!(lst_as_colnames[[i]]),
      na.rm = FALSE, convert = convert, factor_key = factor_key
    )
  })

  # get id data
  id_data <- gathered[[1]][c(id_vars, key)]

  # select non-id vars for each melt operation
  gathered <- lapply(gathered, function(df) df[setdiff(colnames(df), c(id_vars, key))])

  # return cbind operation
  dplyr::bind_cols(id_data, gathered)
}
