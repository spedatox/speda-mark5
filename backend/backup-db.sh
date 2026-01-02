#!/bin/bash
# Speda Database Backup Script
# Run daily via cron: 0 2 * * * ~/speda/backend/backup-db.sh

set -e

BACKUP_DIR="$HOME/speda-backups"
DATE=$(date +%Y%m%d_%H%M%S)
CONTAINER_NAME="speda-backend"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup database from container
echo "📦 Backing up Speda database..."
docker exec $CONTAINER_NAME sqlite3 /app/data/speda.db ".backup '/app/data/speda_backup_${DATE}.db'"
docker cp $CONTAINER_NAME:/app/data/speda_backup_${DATE}.db "$BACKUP_DIR/"
docker exec $CONTAINER_NAME rm /app/data/speda_backup_${DATE}.db

# Keep only last 7 days
find "$BACKUP_DIR" -name "speda_backup_*.db" -mtime +7 -delete

echo "✅ Backup saved: $BACKUP_DIR/speda_backup_${DATE}.db"
echo "📊 Current backups:"
ls -lh "$BACKUP_DIR"
