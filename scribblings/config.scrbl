#lang scribble/manual
@require[@for-label[racket/base "../main.rkt"]]

@title{Config - File based configuration parameters}
@author{Anurag Mendhekar}

@defmodule[config #:no-declare]

@declare-exporting[config]

@italic{Config} is a configuration system for file-based configuration
parameters that can be specified as part of the code, but read from
a configuration file at run time.

The values provided for the configuration parameters are only partially
pre-processed at run-time, but never @racket[eval]'d, to avoid security
issues.

Configuration parameters are typically what would be expected to be provided in the
runtime configuration file. They are declared using one of the following macros.

@defform[(define-config-param param-name
           [#:path] [#:required] [#:default-value v]
           [#:on-repeat repeat-fn])]{
Declares a configuration param with the name @racket[param-name]. The keyword arguments control how
this configuration parameter is read from the configuration file.

The configuration file is a sequence of s-expressions of the form

@codeblock{
(param-name param-value)
}

@racket[param-value] is a value that is implicitly quoted, unless it is of the form
@codeblock{
(env ENV_VAR)
}
in which case the value is read from the environment variable @racket[ENV_VAR] as a string.

@itemlist[
@item{@racket[ #:path ] - The presence of this keyword indicates that the configuration parameter is expected to be a path. The configuration parameter
will be expanded using @racket[expand-user-path] as soon as it is read.}
@item{@racket[ #:required ] - The presence of this keyword indicates that the configuration parameter @italic{must} be provided in the config file. A runtime
exception is thrown if the parameter is not found.}
@item{@racket[ #:default-value v ] - If this configuration parameter is not found in the configuration file, then the default value provided by @racket[v] is assumed.}
@item{@racket[ #:on-repeat repeat-fn ] - When a configuration parameter is read from the file, only its last value is used. If, however, a @racket[repeat-fn] is provided using @racket[#:on-repeat], the value read from the file is invoked on @racket[repeat-fn]. This function can then be used to accumulate values. For example
@codeblock{
(define-config-param repeated-param
  #:default-value '("some-initial-value")
  #:on-repeat (λ (val) (cons val (repeated-param))))
}
If the config file then contains
@codeblock{
(repeated-param "another-value")
}
Then, the value read will be
@codeblock{
("another-value" "some-initial-value")
}
}
]
}

@defform[(define-config-path param-name
           [#:required] [#:default-value v]
           [#:on-repeat repeat-fn])]{
 This is like @racket[define-config-param], but @racket[#:path] is assumed.
}

@defproc[(read-config (fname path-or-string?)) void?]{
Reads the configuration from the file given by @racket[fname]
}

@defproc[(local-config-file-name) string?]{
A function that returns the standard configuration file path. The path is constructed as follows.
@itemlist[
@item{Environment variable @racket[CONFIG_LOCAL_CFG] - The path provided by this environment variable is used as a configuration file. If the path is relative, then it is relative to the current working directory}
@item{Default - The file @racket[local.cfg] under @racket[(current-directory)] is used.}
]

This function is typically used with @racket[read-config]
@codeblock{
(read-config (local-config-file-name))
}
}

@defform[(with-config ((param-name param-val) ...) body ...)]{
  Evaluates @racket[body ...] after binding each provided @racket[param-name] to the corresponding @racket[param-val].
  This form can be used to inject values for configuration parameters without a configuration file.
  This is typically used while running unit tests, so that a test-specific configuration value can be supplied.
  The value overrides any value found in the configuration file.
}
