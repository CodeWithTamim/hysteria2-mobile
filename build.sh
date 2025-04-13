#!/bin/bash

# Colors for cool UI
GREEN="\033[1;32m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
RESET="\033[0m"

# Check if Go is installed
if ! command -v go &> /dev/null; then
    echo -e "${RED}🚨 Go is not installed! Please install it first.${RESET}"
    exit 1
fi

# Display build options
echo -e "${CYAN}🌍 Select a build target:${RESET}"
echo -e "${YELLOW}1) iOS (Hysteria.xcframework)${RESET}"
echo -e "${YELLOW}2) Android (Hysteria.aar & Hysteria-sources.jar)${RESET}"
echo -ne "${BLUE}👉 Enter your choice (1 or 2): ${RESET}"
read -r choice

# Step 1: Install gomobile & gobind
echo -e "${BLUE}📦 Installing gomobile and gobind...${RESET}"
go install golang.org/x/mobile/cmd/gomobile@latest
go install golang.org/x/mobile/cmd/gobind@latest

# Step 2: Initialize gomobile
echo -e "${BLUE}🔧 Initializing gomobile...${RESET}"
gomobile init

# Step 3: Navigate to the app directory
echo -e "${BLUE}📂 Navigating to the app directory...${RESET}"
cd app || { echo -e "${RED}❌ Failed to enter 'app' directory!${RESET}"; exit 1; }

# Build based on user selection
case "$choice" in
    1)
        # Check if Xcode is installed
        if [[ "$(uname)" != "Darwin" ]]; then
            echo -e "${RED}⚠️ iOS builds require macOS with Xcode installed!${RESET}"
            exit 1
        fi
        if ! command -v xcodebuild &> /dev/null; then
            echo -e "${RED}🚨 Xcode is not installed! Please install it before proceeding.${RESET}"
            exit 1
        fi

        echo -e "${GREEN}⚙️  Building Hysteria.xcframework for iOS...${RESET}"
        gomobile bind -trimpath -ldflags "-s -w" --target=ios -o Hysteria.xcframework ./cmd

        # Check if the build was successful
        if [ ! -d "Hysteria.xcframework" ]; then
            echo -e "${RED}❌ Build failed! Hysteria.xcframework was not created.${RESET}"
            exit 1
        fi

        echo -e "${BLUE}🚚 Moving the built framework to 'ios_framework/'...${RESET}"
        mkdir -p ../ios_framework
        mv Hysteria.xcframework ../ios_framework/

        FRAMEWORK_PATH="$(cd ../ios_framework && pwd)/Hysteria.xcframework"
        echo -e "${GREEN}✅ iOS Build Complete!${RESET}"
        echo -e "${CYAN}📍 Framework saved at:${RESET} ${YELLOW}$FRAMEWORK_PATH${RESET}"
        ;;
    2)
        echo -e "${GREEN}⚙️  Building Hysteria.aar & Hysteria-sources.jar for Android...${RESET}"
        gomobile bind -v -androidapi 21 -ldflags='-s -w' -o Hysteria.aar ./cmd

        # Check if the build was successful
        if [ ! -f "Hysteria.aar" ] || [ ! -f "Hysteria-sources.jar" ]; then
            echo -e "${RED}❌ Build failed! Required files were not created.${RESET}"
            exit 1
        fi

        echo -e "${BLUE}🚚 Moving the built AAR & sources JAR to 'android_framework/'...${RESET}"
        mkdir -p ../android_framework
        mv Hysteria.aar ../android_framework/
        mv Hysteria-sources.jar ../android_framework/

        AAR_PATH="$(cd ../android_framework && pwd)/Hysteria.aar"
        JAR_PATH="$(cd ../android_framework && pwd)/Hysteria-sources.jar"
        echo -e "${GREEN}✅ Android Build Complete!${RESET}"
        echo -e "${CYAN}📍 AAR saved at:${RESET} ${YELLOW}$AAR_PATH${RESET}"
        echo -e "${CYAN}📍 Sources JAR saved at:${RESET} ${YELLOW}$JAR_PATH${RESET}"
        ;;
    *)
        echo -e "${RED}❌ Invalid option! Please enter 1 for iOS or 2 for Android.${RESET}"
        exit 1
        ;;
esac