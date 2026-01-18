#!/bin/bash

# Create PediLens Xcode project structure
PROJECT_NAME="PediLens"
PROJECT_DIR="$PROJECT_NAME"

# Create project directory structure
mkdir -p "$PROJECT_DIR/$PROJECT_NAME"
mkdir -p "$PROJECT_DIR/$PROJECT_NAME/Models"
mkdir -p "$PROJECT_DIR/$PROJECT_NAME/Views"
mkdir -p "$PROJECT_DIR/$PROJECT_NAME/ViewModels"
mkdir -p "$PROJECT_DIR/$PROJECT_NAME/Managers"
mkdir -p "$PROJECT_DIR/$PROJECT_NAME/Services"
mkdir -p "$PROJECT_DIR/$PROJECT_NAME/Utilities"
mkdir -p "$PROJECT_DIR/$PROJECT_NAME/Resources"
mkdir -p "$PROJECT_DIR/$PROJECT_NAME/Storage"
mkdir -p "$PROJECT_DIR/${PROJECT_NAME}Tests"

echo "Project structure created successfully"
