¿Podrìas documentar el formato de los mensajes REST, indicando los JSON eseprados?
---

Voy a documentar detalladamente el formato de los mensajes REST utilizados en la comunicación entre la aplicación móvil y el servidor Elixir.



# Documentación de la API REST

Esta documentación detalla los formatos de mensajes JSON utilizados en la comunicación entre la aplicación móvil y el servidor Elixir.

## 1. Registro de Usuario

**Endpoint:** `POST /register`

### Solicitud
```json
{
  "username": "nombre_usuario"
}
```

### Respuesta Exitosa (Código 200)
```json
{
  "status": "ok",
  "message": "Usuario registrado"
}
```

### Respuesta de Error (Código 400)
```json
{
  "status": "error",
  "message": "Nombre de usuario ya en uso"
}
```

## 2. Cierre de Sesión

**Endpoint:** `POST /logout`

### Solicitud
```json
{
  "username": "nombre_usuario"
}
```

### Respuesta (Código 200)
```json
{
  "status": "ok",
  "message": "Sesión cerrada"
}
```

## 3. Envío de Mensaje

**Endpoint:** `POST /send`

### Solicitud
```json
{
  "from": "usuario_origen",
  "to": "usuario_destino",
  "message": "Contenido del mensaje (máximo 256 caracteres)"
}
```

### Respuesta Exitosa (Código 200)
```json
{
  "status": "ok",
  "message": "Mensaje enviado"
}
```

### Respuesta de Error (Código 400)
```json
{
  "status": "error",
  "message": "Usuario destino no encontrado"
}
```

o

```json
{
  "status": "error",
  "message": "El mensaje excede el límite de 256 caracteres"
}
```

## 4. Obtener Lista de Usuarios Conectados

**Endpoint:** `GET /users`

### Respuesta (Código 200)
```json
{
  "users": ["usuario1", "usuario2", "usuario3"]
}
```

## 5. Recibir Mensajes (Long Polling)

**Endpoint:** `GET /messages/:username`

Donde `:username` es el nombre del usuario que consulta por mensajes nuevos.

### Respuesta con Mensaje (Código 200)
```json
{
  "from": "usuario_origen",
  "message": "Contenido del mensaje"
}
```

### Respuesta sin Mensajes (Código 204)
Sin contenido (respuesta vacía después del timeout)


## Explicación de la API REST

La API REST implementada en el servidor Elixir sigue un patrón simple y consistente para todas las operaciones. He documentado en detalle los formatos JSON esperados para cada endpoint:

1. **Registro de Usuario**:
   - Se envía el nombre de usuario
   - El servidor responde con confirmación o error si el nombre ya existe

2. **Cierre de Sesión**:
   - Se envía el nombre de usuario a desconectar
   - El servidor confirma la acción

3. **Envío de Mensajes**:
   - Se especifica remitente, destinatario y contenido del mensaje
   - El servidor valida la longitud del mensaje (máximo 256 caracteres)
   - Se verifica que el destinatario exista

4. **Lista de Usuarios**:
   - Devuelve un array JSON con los nombres de todos los usuarios conectados

5. **Recepción de Mensajes**:
   - Utiliza long polling (espera hasta 30 segundos)
   - Cuando hay un mensaje, lo envía inmediatamente
   - Si no hay mensajes después del timeout, devuelve una respuesta vacía

Para implementar estas comunicaciones en MIT App Inventor, recuerda:

- En los componentes Web, utiliza `PostText` para las solicitudes POST y `Get` para las solicitudes GET
- Para solicitudes POST, puedes usar `JsonTextEncode` para convertir diccionarios a JSON
- Para procesar respuestas, usa `JsonTextDecode` para convertir el JSON recibido a un formato que MIT App Inventor pueda manejar

¿Deseas más detalles sobre algún aspecto específico de la comunicación REST o necesitas ejemplos adicionales de cómo implementar estas comunicaciones en MIT App Inventor?
