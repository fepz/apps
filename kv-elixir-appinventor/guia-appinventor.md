# Guía: Creación de Cliente KV en App Inventor

Esta guía te muestra cómo crear una aplicación móvil en MIT App Inventor que se comunica con nuestro servidor Elixir para almacenar y recuperar datos en una base de datos clave-valor.

## Paso 1: Crear la Interfaz

1. Abre [MIT App Inventor](http://ai2.appinventor.mit.edu)
2. Crea un nuevo proyecto llamado "ClienteKV"
3. Diseña la interfaz según el siguiente esquema:

### Componentes a añadir:

- **Label**: Título "Base de Datos Clave-Valor"
- **HorizontalArrangement1**:
  - **TextBox** llamado `TextBoxClave` (Hint: "Introducir clave")
  - **TextBox** llamado `TextBoxValor` (Hint: "Introducir valor")
- **HorizontalArrangement2**:
  - **Button** llamado `ButtonGuardar` (Text: "Guardar")
  - **Button** llamado `ButtonObtener` (Text: "Obtener")
  - **Button** llamado `ButtonEliminar` (Text: "Eliminar")
- **Button** llamado `ButtonListarTodos` (Text: "Listar Todos")
- **ListView** llamado `ListViewResultados`
- **Web** (Componente no visible)

## Paso 2: Programar la Lógica (Bloques)

### 1. Variables globales
- Crea una variable global `baseUrl` con el valor `"http://TU_IP_SERVIDOR:4000/api/kv"`

### 2. Función para Guardar (ButtonGuardar.Click)
```
Al hacer clic en ButtonGuardar
  Si TextBoxClave.Text está vacío entonces
    mostrar notificación "La clave no puede estar vacía"
  Si no
    llamar a Web.PostText
      Url: concatenar(baseUrl)
      Texto: crear objeto JSON con "key":TextBoxClave.Text, "value":TextBoxValor.Text
      Tipo MIME: "application/json"
```

### 3. Función para Obtener (ButtonObtener.Click)
```
Al hacer clic en ButtonObtener
  Si TextBoxClave.Text está vacío entonces
    mostrar notificación "La clave no puede estar vacía"
  Si no
    llamar a Web.Get
      Url: concatenar(baseUrl, "/", TextBoxClave.Text)
```

### 4. Función para Eliminar (ButtonEliminar.Click)
```
Al hacer clic en ButtonEliminar
  Si TextBoxClave.Text está vacío entonces
    mostrar notificación "La clave no puede estar vacía"
  Si no
    llamar a Web.Delete
      Url: concatenar(baseUrl, "/", TextBoxClave.Text)
```

### 5. Función para Listar Todos (ButtonListarTodos.Click)
```
Al hacer clic en ButtonListarTodos
  llamar a Web.Get
    Url: baseUrl
```

### 6. Manejar respuestas del servidor

```
Cuando Web.GotText
  Si StatusCode = 200 entonces
    Si Url = baseUrl entonces
      // Respuesta para listar todos
      para cada par en JsonTextDecode(ResponseText)
        añadir a ListViewResultados: concatenar(clave, " : ", valor)
    Si no
      // Respuesta para obtener una clave
      establecer TextBoxValor.Text a JsonTextDecode(ResponseText).get("value")
  Si no
    mostrar notificación concatenar("Error: ", StatusCode)
```

## Paso 3: Probar la Aplicación

1. **Configuración del servidor**:
   - Asegúrate de que tu servidor Elixir esté ejecutándose en una IP accesible desde tu dispositivo móvil
   - Actualiza la variable `baseUrl` con la IP correcta de tu servidor

2. **Conexión**:
   - Conecta tu dispositivo Android al mismo Wi-Fi que tu servidor
   - O utiliza el emulador de App Inventor

3. **Pruebas básicas**:
   - Guarda un par clave-valor
   - Recupera un valor usando su clave
   - Lista todos los pares almacenados
   - Elimina una clave
