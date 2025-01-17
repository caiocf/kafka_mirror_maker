#!/bin/sh
# Manter o contêiner ativo (se necessário)
#tail -f /dev/null

# Função para verificar a disponibilidade do Schema Registry
wait_for_schema_registry() {
  echo "Aguardando o Schema Registry em $SCHEMA_REGISTRY_URL estar disponível..."
  for i in $(seq 1 30); do
    if curl -s "$SCHEMA_REGISTRY_URL" > /dev/null; then
      echo "Schema Registry está disponível!"
      return 0
    fi
    echo "Tentativa $i: Schema Registry ainda não está disponível..."
    sleep 2
  done
  echo "Erro: Schema Registry não está disponível após 30 tentativas."
  exit 1
}

# Criação de Tópicos no Kafka
echo -n "Criando tópicos no Kafka e Defindo schema registry avro ..."

# Configurações
BROKER="kafka-source-0:9092"
SCHEMA_REGISTRY_URL="http://schema-registry-0:8081"
TOPIC="usuarios"
SUBJECT="usuarios-value"

cub kafka-ready -b $BROKER 1 60
if [ $? -ne 0 ]; then
  echo -n "Erro: Kafka não está pronto após 60 segundos."
  exit 1
fi

# Aguardar Schema Registry estar pronto
wait_for_schema_registry

# Esquema Avro
SCHEMA='{\"type\":\"record\",\"name\":\"Usuario\",\"fields\":[{\"name\":\"id\",\"type\":\"int\"},{\"name\":\"nome\",\"type\":\"string\"},{\"name\":\"email\",\"type\":\"string\"}]}'


# Registro do Esquema no Schema Registry
echo "Registrando esquema Avro no Schema Registry..."
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  --data "{\"schema\": \"$SCHEMA\"}" \
  "$SCHEMA_REGISTRY_URL/subjects/$SUBJECT/versions")

if [ "$RESPONSE" -eq 200 ] || [ "$RESPONSE" -eq 201 ]; then
  echo -n "Esquema registrado com sucesso no subject '$SUBJECT'."
else
  echo "Falha ao registrar esquema. Código HTTP: $RESPONSE"
  exit 1
fi

echo -n "Definindo o tipo de compatibIlidade do schema $SUBJECT para FORWARD apenas para teste"
curl -X PUT \
  -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  --data "{\"compatibility\": \"BACKWARD\"}" \
  "$SCHEMA_REGISTRY_URL/config/$SUBJECT"


# Criação de Tópicos no Kafka
echo -n "Criando tópicos no Kafka..."
kafka-topics --create \
  --bootstrap-server $BROKER \
  --replication-factor 1 \
  --partitions 3 \
  --topic $TOPIC

echo -n "Tópico '$TOPIC' criado com sucesso."

# Mensagem JSON
#MESSAGE='{"id": 1, "nome": "Miguel", "email": "miguel@example.com"}'

## Publicando a mensagem no Kafka
#echo "$MESSAGE" | kafka-console-producer \
#  --bootstrap-server $BROKER \
#  --topic $TOPIC
#echo "Mensagem publicada no tópico '$TOPIC'."

