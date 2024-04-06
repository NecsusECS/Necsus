#!/bin/bash

set -xeuf -o pipefail

for nimVersion in 2.0.0 1.6.14; do
    for threads in on off; do
        for target in benchmark test; do
            act -W .github/workflows/build.yml -j "$target" --matrix "nim:$nimVersion" --matrix "threads:$threads";
        done
    done

    for project in NecsusECS/NecsusAsteroids NecsusECS/NecsusParticleDemo; do
        act -W .github/workflows/build.yml -j example-projects --matrix "nim:$nimVersion" --matrix "project:$project";
    done

    act -W .github/workflows/build.yml -j readme --matrix "nim:$nimVersion";

    for flag in profile dump archetypes necsusFloat32; do
        act -W .github/workflows/build.yml -j flags --matrix "nim:$nimVersion" --matrix "flag:$flag";
    done
done

act -W .github/workflows/docs.yml