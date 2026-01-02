#!/bin/bash
# Speda Database Restore Script
# Usage: ./restore-db.sh <backup_file>

set -e

if [ -z "$1" ]; then
    echo "❌ Error: No backup file specified"
    echo "Usage: ./restore-db.sh <backup_file>"
    echo ""
    echo "Available backups:"
    ls -lh ~/speda-backups/
    exit 1
fi

BACKUP_FILE="$1"
CONTAINER_NAME="speda-backend"

if [ ! -f "$BACKUP_FILE" ]; then
    echo "❌ Error: Backup file not found: $BACKUP_FILE"
    exit 1
fi

echo "⚠️  WARNING: This will replace the current database!"
read -p "Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cancelled."
    exit 0
fi

# Stop container
echo "🛑 Stopping container..."
cd ~/speda/backend
docker-compose stop

# Copy backup into container
echo "📦 Restoring backup..."
docker cp "$BACKUP_FILE" $CONTAINER_NAME:/app/data/speda.db

# Start container
echo "🚀 Starting container..."
docker-compose start

echo "✅ Database restored!"
docker-compose logs --tail=20
