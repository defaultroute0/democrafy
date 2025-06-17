#!/bin/bash

# Create backup directory
mkdir -p backup_democrafy

# Move all files and directories from Democrafy directory to root
mv Democrafy/Democrafy-Backend .
mv Democrafy/Democrafy-iOS .
mv Democrafy/Democrafy.xcodeproj .
mv Democrafy/DemocrafyTests .
mv Democrafy/DemocrafyUITests .
mv Democrafy/LICENSE .
mv Democrafy/README.md .
mv Democrafy/.gitignore .

# Clean up
rm -rf Democrafy backup_democrafy
