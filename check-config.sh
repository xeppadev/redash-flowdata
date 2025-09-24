#!/bin/bash

# Script de verificación y corrección de la configuración de Redash
# Este script verifica que las URLs de Redis y PostgreSQL estén configuradas correctamente

set -e

echo "🔍 Verificando configuración de Redash..."

# Verificar si existe el archivo .env
if [ ! -f .env ]; then
    echo "⚠️  Archivo .env no encontrado. Creando desde .env.example..."
    cp .env.example .env
fi

# Función para verificar y corregir configuración
check_and_fix_config() {
    local key=$1
    local correct_value=$2
    local file=".env"

    if grep -q "^$key=" "$file"; then
        current_value=$(grep "^$key=" "$file" | cut -d'=' -f2)
        if [ "$current_value" != "$correct_value" ]; then
            echo "🔧 Corrigiendo $key..."
            sed -i.bak "s|^$key=.*|$key=$correct_value|" "$file"
        else
            echo "✅ $key está correctamente configurado"
        fi
    else
        echo "➕ Agregando $key..."
        echo "$key=$correct_value" >> "$file"
    fi
}

# Verificar configuraciones críticas
check_and_fix_config "REDASH_REDIS_URL" "redis://redis:6379/0"
check_and_fix_config "REDASH_DATABASE_URL" "postgresql://postgres@postgres/postgres"
check_and_fix_config "REDASH_CELERY_BROKER" "redis://redis:6379/0"

# Verificar puerto
if ! grep -q "^REDASH_PORT=" .env; then
    echo "➕ Agregando REDASH_PORT..."
    echo "REDASH_PORT=3000" >> .env
fi

# Verificar claves secretas
if grep -q "your-super-secret-key-here-change-this" .env; then
    echo "🔐 Generando claves secretas..."
    SECRET_KEY=$(openssl rand -base64 32 2>/dev/null || date +%s | sha256sum | base64 | head -c 32)
    COOKIE_SECRET=$(openssl rand -base64 32 2>/dev/null || date +%s | sha256sum | base64 | head -c 32)
    CSRF_SECRET=$(openssl rand -base64 32 2>/dev/null || date +%s | sha256sum | base64 | head -c 32)

    sed -i.bak "s/your-super-secret-key-here-change-this/$SECRET_KEY/" .env
    sed -i.bak "s/your-cookie-secret-here-change-this/$COOKIE_SECRET/" .env
    sed -i.bak "s/your-csrf-secret-here-change-this/$CSRF_SECRET/" .env

    rm -f .env.bak
    echo "✅ Claves secretas generadas"
fi

# Verificar dominio
if grep -q "https://your-domain.com" .env; then
    echo "⚠️  IMPORTANTE: Configura REDASH_HOST con tu dominio real en el archivo .env"
fi

echo ""
echo "📋 Configuración actual de conexiones:"
echo "Redis: $(grep REDASH_REDIS_URL .env | cut -d'=' -f2)"
echo "Database: $(grep REDASH_DATABASE_URL .env | cut -d'=' -f2)"
echo "Celery: $(grep REDASH_CELERY_BROKER .env | cut -d'=' -f2)"
echo "Puerto: $(grep REDASH_PORT .env | cut -d'=' -f2)"

echo ""
echo "✅ Verificación completada!"
echo ""
echo "🚀 Ahora puedes desplegar con:"
echo "   docker-compose -f docker-compose.prod.yml up -d"
echo "   o"
echo "   docker-compose -f docker-compose.dokploy.yml up -d"
