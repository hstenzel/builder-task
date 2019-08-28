# builder

A Concourse task to builds Docker images without pushing and without spinning
up a Docker daemon. Currently uses [`img`](http://github.com/genuinetools/img)
for the building and saving.

This repository describes an image which should be used to run a task similar
to `builder-task.yml`. It is intended to use the project's native build system
which may itself build the Docker image. In other words, `docker build` is not
so different than `gcc` in the sense that both may be used to to generate
an artifact.

A stretch goal of this is to support running without `privileged: true`, though
it currently still requires it.

## Motivation

This Docker image is intended to be used to allow a Concourse task to build
a Docker image in the classic "task sandwich" pattern where Concourse
manages the inputs (`get:`) and outputs (`put:`) yet the act of building
Docker images can be done for release images in the same way a developer
would build in their local system.

This builds upon the excellent work of the core Concourse team in the
`concourse/builder-task` repository, but differs in that this image expects
to use the standard build system as it already exists. Whereas `builder-task`
considers the `Dockerfile` to be the root of the build process, here we
consider the `Makefile` to be the root of the build process. Note that there is
nothing magical about a `Makefile`, it could be a stand-in for any build system
that itself masters Docker images.

## Context

There are several scenarios where "just" doing a single `docker build` is lacking.

The first case is where a single repository has many docker image outputs,
as is common in mono-repositories. The build system may already properly handle
the builds, but the release engineers still have to provision the repositories,
manage the outputs and metadata, and upload the resulting artifacts.

Some of these tasks rightly belong in the build process. Some of these tasks
rightly belong in the pipeline. The `concourse-builder-img` approach separates
those roles in a more natural way.

The second case is where a repository is intended to produce an artifact that
is not, or is not just a Docker image.

In such circumstances, it is still helpful to do the entirety of the build inside
the Dockerfile (so that developers can maintain the build system on their
workstations), but we still need results that are both Docker images and other
kinds of artifacts, perhaps from different layers.

Using `concourse-builder-img`, this is an easy pattern to accommodate because
the build system can produce all the images, then the release engineer can expand
the resulting image into a root filesystem to reveal the artifacts.

Once revealed, either as an image .tar file or as a root filesystem, it is
straightforward for the pipeline author to deal with the resulting artifacts.

## Use

Developers work with this project through `make`.

As a developer is iterating over changes, he updates code, runs make, repeats.
This target will `docker build` under the covers; as such it has the lowest
possible barrier to entry possible, and the target should work on any Docker
compatible OS.

`make test` performs a build of `make release` inside a `docker run` and therefore
is very general yet exercises all the image facilities quite completely.

A developer can also `make release`, which simulates what would happen when run
within Concourse. In order to use this target, the `img` tool must be installed,
so this target is limited to Linux users only.

When run in CI, the CI system does a `make release` under the covers. So this target
is exactly the same when run as a developer and when run in CI.

The `make fly-execute` command also runs the build, but it does so with the `fly execute`
command and thus run directly on Concourse. This requires that the user has authorization
to run against CI and that she has the fly command and required connectivity, but
it is still a cross-platform solution with a modest barrier to entry.

However, just doing the `docker build` is enough for most users most of the time,
especially if the bulk of the logic is in the (multistage) Dockerfile. Note also that
it is straightforward to pull root filesystems or docker images out of Docker itself;
these are not the sole providence of `img`.

### Why `make`? Why not other tools?

This is a Goldilocks class problem -- we're shooting for "just right" for a given set
of constraints.

What we realized is that `make` is our current build orchestrator. With `make` and a
very small set of other tools we can stitch the natural Concourse elements into our
own build system.

In the Concourse ecosystem, most configuration is represented as yaml or json. We therefore
include `spruce` and `jq` for interacting with those formats.

Since we use `make`, `coreutils` and `bash` are natural accompanying packages.

Finally, we include `git` since that is our version control.

### Use in a pipeline

See `builder-task.yaml` for an example. However, the result is quite natural.

```
---
platform: linux

image_resource:
  type: registry-image
  source:
    repository: hstenzel/concourse-builder-img

params:
  BUILD_ARGS: --no-console
  PROJECT: concourse-builder-img

inputs:
- name: src

outputs:
- name: release

run:
  dir: src
  path: bash
  args:
  - -cex
  - |
    make clean release
    cp -pr -t ../release release/*

```

We have boilerplate `platform:` and `image_resource:`.

'params:` contains the environment variables that the `Makefile` expects, set
appropriately for CI.

One special environment variable is LOCAL_CA_CERTIFICATE. If this variable is set the cert it
contains will be honored by all tools in the image, including and especially `img`.

`inputs:` and `outputs:` are similarly natural, with only the source code and the release artifacts.

`run:` boils down to a single build command and a copy of the artifacts to the output directory.

## Limitations

- This is not entirely YAML driven.
- Some object to the use of shell at all.
- Still requires privileged.
- Can't switch back to a user inside the container due to Garden.

## Advantages

- `docker build` in a task
- Allow the native build system to be used more directly by Concourse
- Better separation of duties between development and release engineering

## Conclusions

This is intended primarily to spur additional discussion around the docker-builder Concourse pattern.

Comments are always welcome. We've been using a similar approach for some time now, with good results.
