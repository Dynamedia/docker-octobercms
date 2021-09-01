#!/bin/bash

mkdir -p ./data/app/{storage/{app/{media,uploads/public},logs},plugins,themes}
mkdir -p ./data/mysql
touch ./data/app/storage/app/media/.gitkeep
touch ./data/app/storage/app/uploads/public/.gitkeep
touch ./data/app/storage/logs/.gitkeep
touch ./data/app/plugins/.gitkeep
touch ./data/app/themes/.gitkeep
touch ./data/mysql/.gitkeep
