Perfecto, vamos a diseñar la parte de App Inventor para nuestra aplicación DistribuRed. App Inventor es ideal para este proyecto porque permite crear aplicaciones móviles de forma visual y es perfecto para entornos educativos.

# Diseño en App Inventor

## 1. Estructura general de la aplicación

Nuestra aplicación tendrá las siguientes pantallas:
- **Pantalla de inicio (Screen1)**: Para registro del nodo
- **Pantalla principal (MainScreen)**: Interfaz de comunicación y visualización de la red
- **Pantalla de simulación (SimulationScreen)**: Para experimentar con fallos y latencia

## 2. Componentes necesarios

Para empezar, crea un nuevo proyecto en App Inventor y añade estos componentes no visibles:

- **Web Component**: Para comunicación HTTP con el servidor Elixir
- **TinyDB**: Para almacenar el ID del nodo localmente
- **Clock**: Para sondear periódicamente nuevos mensajes
- **Notifier**: Para mostrar notificaciones y alertas

## 3. Pantalla de inicio (Screen1)

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 360 640">
  <!-- Fondo de pantalla -->
  <rect width="360" height="640" fill="#f5f5f5"/>

  <!-- Barra superior -->
  <rect width="360" height="56" fill="#4285F4"/>
  <text x="20" y="35" font-family="Arial" font-size="20" fill="white">DistribuRed - Registro</text>

  <!-- Logo -->
  <circle cx="180" cy="150" r="70" fill="#4285F4" opacity="0.8"/>
  <text x="138" y="160" font-family="Arial" font-size="24" fill="white">DistribuRed</text>

  <!-- Caja de entrada -->
  <rect x="40" y="250" width="280" height="60" rx="5" fill="white" stroke="#ddd"/>
  <text x="50" y="275" font-family="Arial" font-size="14" fill="#888">Nombre del nodo:</text>
  <rect x="50" y="285" width="260" height="2" fill="#4285F4"/>

  <!-- Caja de dirección del servidor -->
  <rect x="40" y="330" width="280" height="60" rx="5" fill="white" stroke="#ddd"/>
  <text x="50" y="355" font-family="Arial" font-size="14" fill="#888">URL del servidor:</text>
  <text x="50" y="375" font-family="Arial" font-size="14" fill="#333">http://192.168.1.x:4000</text>
  <rect x="50" y="385" width="260" height="2" fill="#4285F4"/>

  <!-- Botón de registro -->
  <rect x="120" y="430" width="120" height="50" rx="25" fill="#4CAF50"/>
  <text x="145" y="460" font-family="Arial" font-size="16" fill="white">CONECTAR</text>

  <!-- Estado de conexión -->
  <text x="90" y="520" font-family="Arial" font-size="14" fill="#888">Estado: Esperando conexión</text>
</svg>

```

### Componentes visuales:
- **Label**: Título "DistribuRed"
- **TextBox**: Para introducir el nombre del nodo
- **TextBox**: Para la URL del servidor Elixir (con valor predeterminado)
- **Button**: Para conectarse al servidor

### Bloques de código:

```
// Al pulsar el botón "CONECTAR"
when Button1.Click
  do
    // Validar entrada
    if TextBox1.Text = "" then
      set Notifier1.TextMessage to "Introduce un nombre para tu nodo"
      call Notifier1.ShowAlert
    else
      // Enviar solicitud de registro al servidor
      set Web1.Url to TextBox2.Text & "/register"
      set Web1.RequestHeaders to ["Content-Type: application/json"]
      call Web1.PostText({"node_name": TextBox1.Text})
    end if
  end

// Al recibir respuesta del servidor
when Web1.GotText
  responseContent response
  do
    set responseJson to JsonTextDecode(response)
    if responseJson.get("success") = true then
      // Guardar ID del nodo
      call TinyDB1.StoreValue("node_id", responseJson.get("node_id"))
      call TinyDB1.StoreValue("node_name", TextBox1.Text)
      call TinyDB1.StoreValue("server_url", TextBox2.Text)
      // Ir a la pantalla principal
      open another screen named "MainScreen"
    else
      set Notifier1.TextMessage to "Error: No se pudo conectar al servidor"
      call Notifier1.ShowAlert
    end if
  end
```

## 4. Pantalla principal (MainScreen)

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 360 640">
  <!-- Fondo de pantalla -->
  <rect width="360" height="640" fill="#f5f5f5"/>

  <!-- Barra superior -->
  <rect width="360" height="56" fill="#4285F4"/>
  <text x="20" y="35" font-family="Arial" font-size="20" fill="white">DistribuRed - Red</text>

  <!-- Panel de información de nodo -->
  <rect x="10" y="66" width="340" height="50" rx="5" fill="white" stroke="#ddd"/>
  <text x="20" y="88" font-family="Arial" font-size="14" fill="#333">Mi nodo: Dispositivo de Ana</text>
  <text x="20" y="108" font-family="Arial" font-size="12" fill="#666">ID: 7f8d9a2b-...</text>

  <!-- Sección de nodos disponibles -->
  <rect x="10" y="126" width="340" height="30" rx="5" fill="#E1F5FE"/>
  <text x="20" y="146" font-family="Arial" font-size="14" fill="#333">Nodos disponibles:</text>

  <!-- Lista de nodos -->
  <rect x="10" y="156" width="340" height="140" rx="5" fill="white" stroke="#ddd"/>
  <rect x="20" y="166" width="320" height="30" rx="3" fill="#F5F5F5" stroke="#eee"/>
  <text x="30" y="186" font-family="Arial" font-size="14" fill="#333">Dispositivo de Juan</text>

  <rect x="20" y="206" width="320" height="30" rx="3" fill="#F5F5F5" stroke="#eee"/>
  <text x="30" y="226" font-family="Arial" font-size="14" fill="#333">Dispositivo de María</text>

  <rect x="20" y="246" width="320" height="30" rx="3" fill="#F5F5F5" stroke="#eee"/>
  <text x="30" y="266" font-family="Arial" font-size="14" fill="#333">Dispositivo de Carlos</text>

  <!-- Área de mensaje -->
  <rect x="10" y="306" width="340" height="100" rx="5" fill="white" stroke="#ddd"/>
  <text x="20" y="326" font-family="Arial" font-size="14" fill="#888">Escribe tu mensaje:</text>
  <rect x="20" y="336" width="320" height="60" rx="3" fill="#F5F5F5" stroke="#eee"/>

  <!-- Botón de enviar -->
  <rect x="250" y="416" width="100" height="40" rx="20" fill="#4CAF50"/>
  <text x="275" y="440" font-family="Arial" font-size="14" fill="white">ENVIAR</text>

  <!-- Mensajes recibidos -->
  <rect x="10" y="466" width="340" height="30" rx="5" fill="#E1F5FE"/>
  <text x="20" y="486" font-family="Arial" font-size="14" fill="#333">Mensajes recibidos:</text>

  <!-- Lista de mensajes -->
  <rect x="10" y="496" width="340" height="140" rx="5" fill="white" stroke="#ddd"/>
  <rect x="20" y="506" width="320" height="40" rx="3" fill="#F5F5F5" stroke="#eee"/>
  <text x="30" y="526" font-family="Arial" font-size="14" fill="#333">Juan: Hola a todos</text>
  <text x="280" y="526" font-family="Arial" font-size="10" fill="#888">10:45</text>

  <rect x="20" y="556" width="320" height="40" rx="3" fill="#F5F5F5" stroke="#eee"/>
  <text x="30" y="576" font-family="Arial" font-size="14" fill="#333">Sistema: Nuevo nodo conectado</text>
  <text x="280" y="576" font-family="Arial" font-size="10" fill="#888">10:50</text>

  <!-- Botón de simulación -->
  <circle cx="330" cy="600" r="25" fill="#FF5722"/>
  <text x="323" y="605" font-family="Arial" font-size="24" fill="white">⚙</text>
</svg>

```

### Componentes visuales:
- **Label**: Información del nodo propio
- **ListView**: Lista de nodos disponibles
- **TextBox**: Para escribir mensajes
- **Spinner**: Para seleccionar el destinatario
- **Button**: Para enviar mensajes
- **ListView**: Para mostrar mensajes recibidos
- **Button**: Para acceder a la pantalla de simulación

### Bloques de código:

```
// Al iniciar la pantalla
when MainScreen.Initialize
  do
    // Cargar datos del nodo
    set nodeId to TinyDB1.GetValue("node_id")
    set nodeName to TinyDB1.GetValue("node_name")
    set serverUrl to TinyDB1.GetValue("server_url")
    set LabelNodeInfo.Text to "Mi nodo: " & nodeName & " (ID: " & nodeId & ")"

    // Configurar temporizador para obtener mensajes
    set Clock1.TimerInterval to 2000 // 2 segundos
    set Clock1.TimerEnabled to true

    // Cargar lista de nodos disponibles
    call refreshNodesList
  end

// Función para actualizar la lista de nodos
to refreshNodesList
  do
    set Web1.Url to serverUrl & "/nodes"
    call Web1.Get
  end

// Al obtener la lista de nodos
when Web1.GotText
  responseContent response
  do
    if Web1.Url contains "/nodes" then
      set nodesJson to JsonTextDecode(response)
      if nodesJson.get("success") = true then
        // Limpiar lista existente
        call ListViewNodes.Elements.clear

        // Añadir todos los nodos excepto el propio
        set nodesList to nodesJson.get("nodes")
        for each node in nodesList:
          if node.get("id") ≠ nodeId then
            add node.get("name") to SpinnerRecipients.Elements
            add node.get("id") to global nodesIdsList
          end
        end
      end
    else if Web1.Url contains "/messages" then
      set messagesJson to JsonTextDecode(response)
      if messagesJson.get("success") = true then
        set messages to messagesJson.get("messages")
        for each msg in messages:
          set sender to msg.get("sender_name")
          set content to msg.get("content")
          set timestamp to msg.get("timestamp")
          // Formato para mostrar en la lista
          set messageText to sender & ": " & content
          add messageText to ListViewMessages.Elements

          // Notificar al usuario
          if msg.get("from") ≠ "SYSTEM" then
            set Notifier1.TextMessage to "Nuevo mensaje de " & sender
            call Notifier1.ShowAlert
          end
        end
      end
    end
  end

// Al pulsar el botón de enviar
when ButtonSend.Click
  do
    // Validar mensaje
    if TextBoxMessage.Text = "" then
      set Notifier1.TextMessage to "Escribe un mensaje para enviar"
      call Notifier1.ShowAlert
    else if SpinnerRecipients.Selection = "" then
      set Notifier1.TextMessage to "Selecciona un destinatario"
      call Notifier1.ShowAlert
    else
      // Obtener ID del nodo destinatario
      set selectedIndex to SpinnerRecipients.SelectionIndex
      set recipientId to get global nodesIdsList item selectedIndex

      // Enviar mensaje
      set Web1.Url to serverUrl & "/send"
      set Web1.RequestHeaders to ["Content-Type: application/json"]
      call Web1.PostText({"from_node": nodeId, "to_node": recipientId, "message": TextBoxMessage.Text})

      // Limpiar campo de mensaje
      set TextBoxMessage.Text to ""
    end if
  end

// Temporizador para actualizar mensajes
when Clock1.Timer
  do
    // Actualizar lista de nodos
    call refreshNodesList

    // Obtener mensajes nuevos
    set Web1.Url to serverUrl & "/messages/" & nodeId
    call Web1.Get
  end

// Al pulsar el botón de simulación
when ButtonSimulation.Click
  do
    open another screen named "SimulationScreen"
  end
```

## 5. Pantalla de simulación (SimulationScreen)

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 360 640">
  <!-- Fondo de pantalla -->
  <rect width="360" height="640" fill="#f5f5f5"/>

  <!-- Barra superior -->
  <rect width="360" height="56" fill="#4285F4"/>
  <text x="20" y="35" font-family="Arial" font-size="20" fill="white">DistribuRed - Simulación</text>

  <!-- Contenedor principal -->
  <rect x="10" y="66" width="340" height="554" rx="5" fill="white" stroke="#ddd"/>

  <!-- Título de sección -->
  <rect x="10" y="76" width="340" height="40" rx="5" fill="#E1F5FE"/>
  <text x="20" y="102" font-family="Arial" font-size="16" fill="#333">Simulación de fallos</text>

  <!-- Selector de nodo -->
  <text x="20" y="142" font-family="Arial" font-size="14" fill="#666">Seleccionar nodo:</text>
  <rect x="20" y="152" width="320" height="40" rx="5" fill="#F5F5F5" stroke="#ddd"/>
  <text x="30" y="177" font-family="Arial" font-size="14" fill="#333">▼ Dispositivo de Juan</text>

  <!-- Botones de fallo -->
  <rect x="20" y="212" width="150" height="40" rx="20" fill="#FF5722"/>
  <text x="50" y="237" font-family="Arial" font-size="14" fill="white">Simular fallo</text>

  <rect x="190" y="212" width="150" height="40" rx="20" fill="#4CAF50"/>
  <text x="210" y="237" font-family="Arial" font-size="14" fill="white">Restaurar nodo</text>

  <!-- Separador -->
  <line x1="30" y1="272" x2="330" y2="272" stroke="#ddd" stroke-width="2"/>

  <!-- Título de sección -->
  <rect x="10" y="292" width="340" height="40" rx="5" fill="#E1F5FE"/>
  <text x="20" y="318" font-family="Arial" font-size="16" fill="#333">Simulación de latencia</text>

  <!-- Selector de latencia -->
  <text x="20" y="358" font-family="Arial" font-size="14" fill="#666">Retraso (ms):</text>

  <!-- Slider de latencia -->
  <line x1="20" y1="390" x2="320" y2="390" stroke="#ddd" stroke-width="4" stroke-linecap="round"/>
  <circle cx="170" cy="390" r="15" fill="#4285F4"/>

  <text x="20" y="420" font-family="Arial" font-size="12" fill="#666">0 ms</text>
  <text x="160" y="420" font-family="Arial" font-size="14" fill="#333">1000 ms</text>
  <text x="300" y="420" font-family="Arial" font-size="12" fill="#666">3000 ms</text>

  <!-- Botón aplicar latencia -->
  <rect x="110" y="440" width="140" height="40" rx="20" fill="#4285F4"/>
  <text x="130" y="465" font-family="Arial" font-size="14" fill="white">Aplicar retraso</text>

  <!-- Separador -->
  <line x1="30" y1="500" x2="330" y2="500" stroke="#ddd" stroke-width="2"/>

  <!-- Título de sección -->
  <rect x="10" y="520" width="340" height="40" rx="5" fill="#E1F5FE"/>
  <text x="20" y="546" font-family="Arial" font-size="16" fill="#333">Estado de la red</text>

  <!-- Información de estado -->
  <rect x="20" y="570" width="320" height="40" rx="5" fill="#F5F5F5" stroke="#ddd"/>
  <text x="30" y="595" font-family="Arial" font-size="14" fill="#333">3 nodos activos, 1 nodo caído</text>
</svg>

```

### Componentes visuales:
- **Spinner**: Para seleccionar el nodo a simular
- **Button**: Para simular fallo de nodo
- **Button**: Para restaurar nodo
- **Slider**: Para ajustar la latencia de la red
- **Button**: Para aplicar la latencia
- **Label**: Para mostrar el estado actual de la red

### Bloques de código:

```
// Al iniciar la pantalla
when SimulationScreen.Initialize
  do
    // Cargar datos guardados
    set nodeId to TinyDB1.GetValue("node_id")
    set serverUrl to TinyDB1.GetValue("server_url")

    // Actualizar estado de la red
    call updateNetworkStatus

    // Obtener lista de nodos para la simulación
    set Web1.Url to serverUrl & "/nodes"
    call Web1.Get
  end

// Al obtener la lista de nodos
when Web1.GotText
  responseContent response
  do
    if Web1.Url contains "/nodes" then
      set nodesJson to JsonTextDecode(response)
      if nodesJson.get("success") = true then
        // Limpiar lista existente
        call SpinnerNodes.Elements.clear

        // Añadir todos los nodos a la lista
        set nodesList to nodesJson.get("nodes")
        for each node in nodesList:
          add node.get("name") to SpinnerNodes.Elements
          add node.get("id") to global simulationNodesIdsList
        end
      end
    else if Web1.Url contains "/simulate/failure" then
      // Actualizar estado tras simulación
      call updateNetworkStatus
    else if Web1.Url contains "/simulate/delay" then
      set responseJson to JsonTextDecode(response)
      if responseJson.get("success") = true then
        set Notifier1.TextMessage to "Latencia configurada a: " & SliderLatency.ThumbPosition & " ms"
        call Notifier1.ShowAlert
      end
    end
  end

// Actualizar estado de la red
to updateNetworkStatus
  do
    set Web1.Url to serverUrl & "/nodes"
    call Web1.Get

    // Procesamiento asíncrono en GotText
  end

// Al pulsar el botón de simular fallo
when ButtonFailure.Click
  do
    if SpinnerNodes.Selection = "" then
      set Notifier1.TextMessage to "Selecciona un nodo primero"
      call Notifier1.ShowAlert
    else
      // Obtener ID del nodo seleccionado
      set selectedIndex to SpinnerNodes.SelectionIndex
      set targetNodeId to get global simulationNodesIdsList item selectedIndex

      // Enviar solicitud de simulación
      set Web1.Url to serverUrl & "/simulate/failure"
      set Web1.RequestHeaders to ["Content-Type: application/json"]
      call Web1.PostText({"node_id": targetNodeId})
    end if
  end

// Al pulsar el botón de restaurar nodo
when ButtonRestore.Click
  do
    if SpinnerNodes.Selection = "" then
      set Notifier1.TextMessage to "Selecciona un nodo primero"
      call Notifier1.ShowAlert
    else
      // Obtener ID del nodo seleccionado
      set selectedIndex to SpinnerNodes.SelectionIndex
      set targetNodeId to get global simulationNodesIdsList item selectedIndex

      // Enviar solicitud de restauración (usa el mismo endpoint)
      set Web1.Url to serverUrl & "/simulate/failure"
      set Web1.RequestHeaders to ["Content-Type: application/json"]
      call Web1.PostText({"node_id": targetNodeId})
    end if
  end

// Al pulsar el botón de aplicar latencia
when ButtonApplyLatency.Click
  do
    // Obtener valor del slider
    set latencyValue to SliderLatency.ThumbPosition

    // Enviar solicitud de latencia
    set Web1.Url to serverUrl & "/simulate/delay"
    set Web1.RequestHeaders to ["Content-Type: application/json"]
    call Web1.PostText({"delay_ms": latencyValue})
  end

// Al pulsar el botón volver
when ButtonBack.Click
  do
    open another screen named "MainScreen"
  end
```

## 6. Exportación y distribución

Una vez completado el diseño de la aplicación, debes:

1. **Exportar el proyecto** desde App Inventor:
   - En el menú "Build", selecciona "App (provide QR code for .apk)"
   - También puedes usar "App (save .apk to my computer)"

2. **Distribuir la aplicación** a los estudiantes:
   - Compartiendo el archivo APK
   - Usando el código QR generado
   - Compartiendo el proyecto para que los estudiantes puedan modificarlo

## 7. Consideraciones educativas

Al usar esta aplicación con estudiantes, considera:

1. **Preparar ejercicios guiados**:
   - Tarea 1: Conectarse a la red y enviar un mensaje a otro estudiante
   - Tarea 2: Observar qué sucede cuando un nodo falla
   - Tarea 3: Experimentar con distintos niveles de latencia

2. **Explicaciones complementarias**:
   - Mostrar el código Elixir y explicar cómo se relaciona con la aplicación
   - Explicar conceptos como estado compartido, tolerancia a fallos, latencia

3. **Ampliaciones posibles**:
   - Añadir funcionalidad de "multicast" (mensaje a varios nodos)
   - Implementar un algoritmo de consenso simple
   - Crear visualizaciones de la topología de la red

## 8. Recursos adicionales

Para ayudar a los estudiantes a comprender mejor App Inventor:

1. **Tutorial básico**: Crear una guía paso a paso de cómo se construyó la aplicación
2. **Bloques comentados**: Proporcionar capturas de los bloques con explicaciones
3. **Retos**: Proponer mejoras que los estudiantes puedan implementar

¿Hay algún aspecto específico de App Inventor que te gustaría que profundizara? ¿O preferirías que hablemos sobre cómo integrar ambas partes (Elixir y App Inventor) en un entorno educativo?
