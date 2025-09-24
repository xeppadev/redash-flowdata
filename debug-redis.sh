#!/bin/bash

# Script de debug para verificar la configuración de Redis en el contenedor

echo "🔍 Verificando configuración de Redis en el contenedor..."

# Función para verificar variable en contenedor
check_container_env() {
    local container_name=$1
    local var_name=$2

    echo "📋 Verificando $var_name en $container_name:"

    # Intentar obtener la variable de entorno del contenedor
    value=$(docker exec "${container_name}" printenv "$var_name" 2>/dev/null || echo "NO_ENCONTRADA")

    if [ "$value" = "NO_ENCONTRADA" ]; then
        echo "  ❌ Variable $var_name no encontrada"
    else
        echo "  ✅ $var_name = $value"
    fi
}

# Encontrar contenedores de redash
echo "🔍 Buscando contenedores de Redash..."
containers=$(docker ps --format "table {{.Names}}" | grep -E "(redash|server)" | grep -v NAMES)

if [ -z "$containers" ]; then
    echo "❌ No se encontraron contenedores de Redash ejecutándose"
    echo ""
    echo "📋 Contenedores actuales:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    exit 1
fi

echo "📦 Contenedores encontrados:"
echo "$containers"
echo ""

# Verificar variables críticas en cada contenedor
for container in $containers; do
    echo "🔍 Verificando contenedor: $container"
    echo "----------------------------------------"

    # Verificar si el contenedor está corriendo
    status=$(docker inspect "$container" --format='{{.State.Status}}' 2>/dev/null || echo "not_found")

    if [ "$status" != "running" ]; then
        echo "  ⚠️  Contenedor no está corriendo (estado: $status)"
        continue
    fi

    # Verificar variables críticas
    check_container_env "$container" "REDASH_REDIS_URL"
    check_container_env "$container" "REDASH_DATABASE_URL"
    check_container_env "$container" "REDASH_CELERY_BROKER"

    # Verificar conectividad a Redis desde el contenedor
    echo ""
    echo "🔗 Verificando conectividad a Redis desde $container:"

    redis_test=$(docker exec "$container" timeout 5 redis-cli -h redis -p 6379 ping 2>/dev/null || echo "FAILED")

    if [ "$redis_test" = "PONG" ]; then
        echo "  ✅ Conectividad a Redis OK"
    else
        echo "  ❌ No se puede conectar a Redis: $redis_test"
    fi

    echo ""
done

# Verificar estado de Redis
echo "🔍 Verificando servicio Redis..."
redis_containers=$(docker ps --format "table {{.Names}}" | grep redis | grep -v NAMES)

if [ -z "$redis_containers" ]; then
    echo "❌ No se encontró contenedor Redis ejecutándose"
else
    for redis_container in $redis_containers; do
        echo "📦 Redis container: $redis_container"
        redis_status=$(docker exec "$redis_container" redis-cli ping 2>/dev/null || echo "FAILED")
        if [ "$redis_status" = "PONG" ]; then
            echo "  ✅ Redis está respondiendo correctamente"
        else
            echo "  ❌ Redis no está respondiendo: $redis_status"
        fi
    done
fi

echo ""
echo "🔍 Verificando red Docker..."
networks=$(docker network ls | grep redash)
if [ -n "$networks" ]; then
    echo "✅ Red redash encontrada:"
    echo "$networks"
else
    echo "❌ Red redash no encontrada"
fi

echo ""
echo "📋 Logs recientes del servidor (últimas 10 líneas):"
echo "================================================"
if [ -n "$containers" ]; then
    server_container=$(echo "$containers" | head -n1)
    docker logs --tail=10 "$server_container" 2>&1
fi
