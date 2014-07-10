# Contributing to pg_search

First off, if you experience a bug, we welcome you to report it. Please provide a minimal test case showing the code that you ran, its output, and what you expected the output to be instead. If you are able to fix the bug and make a pull request, we are much more likely to get it resolved quickly, but don't feel bad to just report an issue if you don't know how to fix it.

pg_search supports Ruby 1.9.2 and higher, Active Record 3.1 and higher, and PostgreSQL 8.0 and higher. It can be hard to test against all of those versions, but please do your best to avoid features that are only available in newer versions. For example, don't use Ruby 2.0's `prepend` keyword.

If you have a substantial feature to add, you might want to discuss it first on the [mailing list](https://groups.google.com/forum/#!forum/casecommons-dev). We might have thought hard about it already, and can sometimes help with tips and tricks.

When in doubt, go ahead and make a pull request. If something needs tweaking or rethinking, we will do our best to respond and make that clear.

Don't be discouraged if the maintainers ask you to change your code. We are always appreciative when people work hard to modify our code, but we also have a lot of opinions about coding style and object design.

Run the tests by running rake. It will update all gems to their latest version. This is by design, because we want to be proactive about compatibility with other libraries. To test against a specific version of Active Record, you can set the `ACTIVE_RECORD_VERSION` environment variable.

    $ ACTIVE_RECORD_VERSION=3.1 rake

Last, but not least, have fun! pg_search is a labor of love.