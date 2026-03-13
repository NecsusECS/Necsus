#!/bin/bash

set -xeuf -o pipefail

for nimVersion in 2.0.10 1.6.14; do
    for target in benchmark test; do
        act -W .github/workflows/build.yml -j "$target" --matrix "nim:$nimVersion";
    done

    for project in NecsusECS/NecsusAsteroids NecsusECS/NecsusParticleDemo; do
        act -W .github/workflows/build.yml -j example-projects --matrix "nim:$nimVersion" --matrix "project:$project";
    done

    act -W .github/workflows/build.yml -j readme --matrix "nim:$nimVersion";
    act -W .github/workflows/build.yml -j fast-compile --matrix "nim:$nimVersion";
done

for flag in profile dump archetypes necsusSystemTrace necsusEntityTrace necsusEventTrace necsusQueryTrace necsusSaveTrace; do
    act -W .github/workflows/build.yml -j flags --matrix "nim:2.0.10" --matrix "flag:$flag";
done

act -W .github/workflows/docs.yml
