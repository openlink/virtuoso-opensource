# OpenLink Contributor Guidelines

## About This Document

This document describes how to contribute to the OpenLink Virtuoso
Open-Source Edition project, what we expect from contributions, how
patches are processed and how we treat AI-assisted work. Our stance
is *permissive but responsible* — we welcome contributions however
they are produced, but the contributor must have vetted their own
work before submitting it.

## Code of Conduct

The Virtuoso Open-Source Edition project is an honest, inclusive
and respectful environment. As project hosts, OpenLink Software
will act as necessary to maintain this ethos.

## Use of AI

You may use AI and LLM tools to assist with any part of a contribution
subject to the following considerations:

* Responsibility always remains with the human behind the change
* You must have reviewed, understood and tested the patch yourself
and be able to explain it
* Disclosure is encouraged for small patches and required when
patches are significant. Where AI played a significant role in
identifying the issue or generating the fix, add a trailer to your
commit message:

```
Assisted-by: {LLM}:{model}
Signed-off-by: {person name}
```

* We do not permit automated community interaction - no bot- or
agent-generated PRs, generated reviews or discussion

* Confidentiality: do not include private, sensitive or security-related
information in prompts to third-party AI tools or LLM services.


## Patch Workflow

* Incoming patches will be reviewed and actioned as our schedule
permits. We hope to acknowledge new reports within a matter of days.

* If your bug or patch merits it, or you are unsure how best to
handle a particular situation, either raise a [Github issue](https://github.com/openlink/virtuoso-opensource/issues) 
or email us on vos.admin@openlinksw.com.

* You may submit a contribution either as a GitHub pull request or as
a patch series generated with `git format-patch` and emailed to
vos.admin@openlinksw.com, whichever you prefer. See
[README.GIT.md](README.GIT.md) for how to prepare patches.

* We encourage each contribution to be a feature branch, where each
branch implements one feature, and each commit is a reasonable step
unit of work without unnecessary code churn. Each pull request or
patch series should implement one feature or fix; if you find yourself
touching several areas of the code for unrelated reasons, split the
work into separate branches.

### Preferred Commit Pattern

We recommend commit messages in this format:

```
{1-line description}

* implementation notes and gotchas
...
* specific example(s) illustrating the function and consequences of the commit

[Assisted-by: {LLM}:{model}]
Signed-off-by: {person name}
```

## Issues

To raise a public discussion, create a [Github issue](https://github.com/openlink/virtuoso-opensource/issues).

To report sensitive or security-related matters, see our [Security policy](SECURITY.md).


Do not open public issues for embargoed security reports, and do
not share such reports with third-party AI services.

## Tests

Functional changes should be accompanied by either documentation
or tests to demonstrate the fix or feature. Include your manual
verification steps in the PR description.

## Licensing & Provenance

By submitting a patch via any channel you license your contribution
to the project under its licence(s), and you confirm it is your
original work (or that you have the right to submit it). This is
as true when using generative AI tooling as it is when using materials
from public websites: you must disclose embedded material that is
not your original creation and identify its licence. If your employer
holds rights over your work, you are responsible for securing any
permission needed to contribute it.
