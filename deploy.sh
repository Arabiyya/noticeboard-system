#!/bin/bash

# Prompt for base directory and domain
read -p "Enter base directory (default: $HOME/noticeboard): " BASE_DIR
BASE_DIR=${BASE_DIR:-$HOME/noticeboard}

read -p "Enter main domain (e.g., noticeboard.domain.tld): " MAIN_DOMAIN
read -p "Enter API domain (e.g., api.noticeboard.domain.tld): " API_DOMAIN

# Define subdirectories
BACKEND_DIR=$BASE_DIR/backend
FRONTEND_DIR=$BASE_DIR/frontend
ADMIN_DIR=$BASE_DIR/admin

# Clean previous builds
echo "Cleaning previous deployment..."
rm -rf $BACKEND_DIR/* $FRONTEND_DIR/* $ADMIN_DIR/*

# Create directories
echo "Creating deployment directories..."
mkdir -p $BACKEND_DIR $FRONTEND_DIR $ADMIN_DIR

# Build Backend
echo "Building backend..."
cd noticeboard-backend || exit 1
yarn install && yarn build || { echo "Backend build failed!"; exit 1; }
cp -r dist $BACKEND_DIR
cp package.json $BACKEND_DIR
cp .env.example $BACKEND_DIR/.env
cd ..

# Build Admin App
echo "Building admin panel..."
cd noticeboard-admin || exit 1
yarn install && yarn build || { echo "Admin panel build failed!"; exit 1; }
cp -r dist/* $ADMIN_DIR
cd ..

# Build Client App
echo "Building client app..."
cd noticeboard-frontend || exit 1
yarn install && yarn build || { echo "Client app build failed!"; exit 1; }
cp -r dist/* $FRONTEND_DIR
cd ..

# Copy and update NGINX config
echo "Setting up NGINX configuration..."
cp noticeboard-example $BASE_DIR/noticeboard.conf
sed -i "s|MAIN_DOMAIN|$MAIN_DOMAIN|g" $BASE_DIR/noticeboard.conf
sed -i "s|API_DOMAIN|$API_DOMAIN|g" $BASE_DIR/noticeboard.conf
sed -i "s|BASE_DIR|$BASE_DIR|g" $BASE_DIR/noticeboard.conf
sudo cp $BASE_DIR/noticeboard.conf /etc/nginx/sites-available/noticeboard
sudo ln -s /etc/nginx/sites-available/noticeboard /etc/nginx/sites-enabled/
sudo nginx -t || { echo "NGINX configuration test failed!"; exit 1; }
sudo systemctl reload nginx

# Detect Node.js path
NODE_PATH=$(which node || echo "Node.js not found. Please ensure Node.js is installed and available in PATH.")
if [[ "$NODE_PATH" == "Node.js not found." ]]; then
  echo "$NODE_PATH"
  exit 1
fi

# Copy and update systemd service file
echo "Setting up systemd service..."
cp noticeboard-api.service.example $BASE_DIR/noticeboard-api.service
sed -i "s|BASE_DIR|$BASE_DIR|g" $BASE_DIR/noticeboard-api.service
sed -i "s|NODE_PATH|$NODE_PATH|g" $BASE_DIR/noticeboard-api.service
sed -i "s|USER|$(whoami)|g" $BASE_DIR/noticeboard-api.service
sudo cp $BASE_DIR/noticeboard-api.service /etc/systemd/system/noticeboard-api.service
sudo systemctl daemon-reload
sudo systemctl enable noticeboard-api
sudo systemctl start noticeboard-api

echo "Build and deployment setup complete."
echo "Files are in $BASE_DIR. NGINX config is in /etc/nginx/sites-available/noticeboard."
echo "Systemd service is set up and running."
