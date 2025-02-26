# Primero, necesitamos crear un nuevo proyecto Phoenix
# Ejecuta estos comandos en tu terminal:

# mix archive.install hex phx_new
# mix phx.new survey_app --database postgres

# Estructura de Directorios
# /survey_app
#   /lib
#     /survey_app
#       /surveys - Contexto para manejar encuestas
#       /accounts - Contexto para manejar usuarios
#     /survey_app_web
#       /controllers
#       /templates
#       /views

# Configuración de la base de datos (config/dev.exs)
# Modifica según tu configuración local

# Modelo de datos
# Primero, vamos a crear el esquema para las encuestas

# Creamos los modelos/esquemas:
# mix phx.gen.schema Surveys.Survey surveys title:string description:text active:boolean
# mix phx.gen.schema Surveys.Question questions survey_id:references:surveys text:string type:string required:boolean
# mix phx.gen.schema Surveys.Option options question_id:references:questions text:string is_other:boolean
# mix phx.gen.schema Surveys.Response responses survey_id:references:surveys user_id:references:users ip_address:string completed_at:utc_datetime
# mix phx.gen.schema Surveys.Answer answers response_id:references:responses question_id:references:questions option_id:references:options text:text

# Ahora, el contexto para manejar encuestas (lib/survey_app/surveys.ex)
defmodule SurveyApp.Surveys do
  import Ecto.Query
  alias SurveyApp.Repo
  alias SurveyApp.Surveys.{Survey, Question, Option, Response, Answer}
  alias SurveyApp.Accounts.User

  # Funciones para manejar encuestas
  def list_active_surveys do
    Survey
    |> where(active: true)
    |> Repo.all()
  end

  def get_survey!(id) do
    Survey
    |> Repo.get!(id)
    |> Repo.preload(questions: [options: []])
  end

  def create_survey(attrs \\ %{}) do
    %Survey{}
    |> Survey.changeset(attrs)
    |> Repo.insert()
  end

  # Funciones para preguntas y opciones
  def create_question(survey, attrs \\ %{}) do
    %Question{}
    |> Question.changeset(attrs |> Map.put("survey_id", survey.id))
    |> Repo.insert()
  end

  def create_option(question, attrs \\ %{}) do
    %Option{}
    |> Option.changeset(attrs |> Map.put("question_id", question.id))
    |> Repo.insert()
  end

  # Funciones para respuestas
  def start_response(survey_id, user_id, ip_address) do
    %Response{}
    |> Response.changeset(%{
      survey_id: survey_id,
      user_id: user_id,
      ip_address: ip_address
    })
    |> Repo.insert()
  end

  def complete_response(response_id) do
    response = Repo.get!(Response, response_id)

    response
    |> Response.changeset(%{completed_at: DateTime.utc_now()})
    |> Repo.update()
  end

  def create_answer(attrs \\ %{}) do
    %Answer{}
    |> Answer.changeset(attrs)
    |> Repo.insert()
  end

  # Verificar si un usuario ya respondió una encuesta
  def user_already_responded?(survey_id, user_id, ip_address) do
    query = from r in Response,
            where: r.survey_id == ^survey_id and
                  (r.user_id == ^user_id or r.ip_address == ^ip_address) and
                  not is_nil(r.completed_at)

    Repo.exists?(query)
  end

  # Obtener resultados de una encuesta
  def get_survey_results(survey_id) do
    survey = get_survey!(survey_id)

    Enum.map(survey.questions, fn question ->
      # Para cada pregunta, obtenemos el conteo de cada opción
      option_counts = from a in Answer,
                      join: r in Response, on: a.response_id == r.id,
                      where: a.question_id == ^question.id and
                             r.completed_at != nil,
                      group_by: a.option_id,
                      select: {a.option_id, count(a.id)}
                      |> Repo.all()
                      |> Map.new()

      # Para respuestas con texto libre (opción "otra")
      other_answers = from a in Answer,
                      join: o in Option, on: a.option_id == o.id,
                      join: r in Response, on: a.response_id == r.id,
                      where: a.question_id == ^question.id and
                             o.is_other == true and
                             r.completed_at != nil,
                      select: a.text
                      |> Repo.all()

      %{
        question: question,
        option_counts: option_counts,
        other_answers: other_answers
      }
    end)
  end
end

# Esquema para usuarios (lib/survey_app/accounts/user.ex)
defmodule SurveyApp.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :name, :string
    field :email, :string

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :email])
    |> validate_required([:name, :email])
    |> unique_constraint(:email)
  end
end

# Contexto para usuarios (lib/survey_app/accounts.ex)
defmodule SurveyApp.Accounts do
  import Ecto.Query
  alias SurveyApp.Repo
  alias SurveyApp.Accounts.User

  def get_user!(id), do: Repo.get!(User, id)

  def get_user_by_email(email) do
    Repo.get_by(User, email: email)
  end

  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  def get_or_create_user(attrs) do
    case get_user_by_email(attrs.email) do
      nil -> create_user(attrs)
      user -> {:ok, user}
    end
  end
end

# Controlador de encuestas (lib/survey_app_web/controllers/survey_controller.ex)
defmodule SurveyAppWeb.SurveyController do
  use SurveyAppWeb, :controller
  alias SurveyApp.Surveys
  alias SurveyApp.Accounts

  def index(conn, _params) do
    surveys = Surveys.list_active_surveys()
    render(conn, "index.html", surveys: surveys)
  end

  def show(conn, %{"id" => id}) do
    survey = Surveys.get_survey!(id)
    render(conn, "show.html", survey: survey)
  end

  def start(conn, %{"id" => id, "user" => user_params}) do
    survey = Surveys.get_survey!(id)
    ip_address = conn.remote_ip |> :inet.ntoa() |> to_string()

    with {:ok, user} <- Accounts.get_or_create_user(user_params) do
      # Verificar si el usuario ya respondió
      if Surveys.user_already_responded?(id, user.id, ip_address) do
        conn
        |> put_flash(:error, "Ya has completado esta encuesta anteriormente.")
        |> redirect(to: Routes.survey_path(conn, :show, survey))
      else
        {:ok, response} = Surveys.start_response(survey.id, user.id, ip_address)

        conn
        |> put_session(:response_id, response.id)
        |> redirect(to: Routes.survey_path(conn, :answer, survey))
      end
    else
      {:error, changeset} ->
        render(conn, "show.html", survey: survey, changeset: changeset)
    end
  end

  def answer(conn, %{"id" => id}) do
    survey = Surveys.get_survey!(id)
    response_id = get_session(conn, :response_id)

    if is_nil(response_id) do
      conn
      |> put_flash(:error, "Debes registrarte para responder la encuesta.")
      |> redirect(to: Routes.survey_path(conn, :show, survey))
    else
      render(conn, "answer.html", survey: survey, response_id: response_id)
    end
  end

  def submit(conn, %{"id" => id, "answers" => answers}) do
    survey = Surveys.get_survey!(id)
    response_id = get_session(conn, :response_id)

    if is_nil(response_id) do
      conn
      |> put_flash(:error, "Sesión inválida. Por favor, vuelve a empezar.")
      |> redirect(to: Routes.survey_path(conn, :show, survey))
    else
      # Procesar cada respuesta
      Enum.each(answers, fn {question_id, answer_data} ->
        option_id = answer_data["option_id"]
        text = answer_data["text"]

        Surveys.create_answer(%{
          response_id: response_id,
          question_id: question_id,
          option_id: option_id,
          text: text
        })
      end)

      # Marcar la encuesta como completada
      Surveys.complete_response(response_id)

      conn
      |> delete_session(:response_id)
      |> put_flash(:info, "¡Gracias por completar la encuesta!")
      |> redirect(to: Routes.survey_path(conn, :index))
    end
  end

  # Ver resultados de la encuesta
  def results(conn, %{"id" => id}) do
    survey = Surveys.get_survey!(id)
    results = Surveys.get_survey_results(id)

    render(conn, "results.html", survey: survey, results: results)
  end
end

# Rutas (lib/survey_app_web/router.ex)
defmodule SurveyAppWeb.Router do
  use SurveyAppWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", SurveyAppWeb do
    pipe_through :browser

    get "/", PageController, :index

    get "/surveys", SurveyController, :index
    get "/surveys/:id", SurveyController, :show
    post "/surveys/:id/start", SurveyController, :start
    get "/surveys/:id/answer", SurveyController, :answer
    post "/surveys/:id/submit", SurveyController, :submit
    get "/surveys/:id/results", SurveyController, :results
  end
end

# Templates

# index.html.eex (Listado de encuestas disponibles)
<h1>Encuestas Disponibles</h1>

<div class="surveys-list">
  <%= for survey <- @surveys do %>
    <div class="survey-card">
      <h2><%= survey.title %></h2>
      <p><%= survey.description %></p>
      <%= link "Participar", to: Routes.survey_path(@conn, :show, survey), class: "btn btn-primary" %>
    </div>
  <% end %>
</div>

# show.html.eex (Página de inicio de la encuesta con registro de usuario)
<h1><%= @survey.title %></h1>
<p><%= @survey.description %></p>

<div class="registration-form">
  <h2>Ingresa tus datos para comenzar</h2>

  <%= form_for @conn, Routes.survey_path(@conn, :start, @survey), [as: :user], fn f -> %>
    <div class="form-group">
      <%= label f, :name, "Nombre" %>
      <%= text_input f, :name, required: true, class: "form-control" %>
    </div>

    <div class="form-group">
      <%= label f, :email, "Email" %>
      <%= email_input f, :email, required: true, class: "form-control" %>
    </div>

    <%= submit "Comenzar Encuesta", class: "btn btn-primary" %>
  <% end %>
</div>

# answer.html.eex (Formulario para responder la encuesta)
<h1><%= @survey.title %></h1>

<%= form_for @conn, Routes.survey_path(@conn, :submit, @survey), [as: :answers], fn f -> %>
  <%= for question <- @survey.questions do %>
    <div class="question">
      <h3><%= question.text %></h3>

      <%= for option <- question.options do %>
        <div class="option">
          <%= if option.is_other do %>
            <div class="other-option">
              <%= radio_button f, "#{question.id}[option_id]", option.id, class: "other-radio" %>
              <%= label :other, option.text %>
              <%= text_input f, "#{question.id}[text]", class: "other-text" %>
            </div>
          <% else %>
            <div class="regular-option">
              <%= radio_button f, "#{question.id}[option_id]", option.id %>
              <%= label :option, option.text %>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
  <% end %>

  <%= submit "Enviar Respuestas", class: "btn btn-primary" %>
<% end %>

# results.html.eex (Visualización de resultados)
<h1>Resultados: <%= @survey.title %></h1>

<div class="results-container">
  <%= for result <- @results do %>
    <div class="question-result">
      <h3><%= result.question.text %></h3>

      <div class="chart-container">
        <canvas id="chart-<%= result.question.id %>" width="400" height="200"></canvas>
      </div>

      <% if length(result.other_answers) > 0 do %>
        <div class="other-answers">
          <h4>Respuestas personalizadas:</h4>
          <ul>
            <%= for text <- result.other_answers do %>
              <li><%= text %></li>
            <% end %>
          </ul>
        </div>
      <% end %>
    </div>
  <% end %>
</div>

<script>
  document.addEventListener('DOMContentLoaded', function() {
    <%= for result <- @results do %>
      var ctx = document.getElementById('chart-<%= result.question.id %>').getContext('2d');

      var labels = [];
      var data = [];
      var backgroundColors = [];

      <% for option <- result.question.options do %>
        <% if !option.is_other do %>
          labels.push('<%= option.text %>');
          data.push(<%= Map.get(result.option_counts, option.id, 0) %>);
          backgroundColors.push(getRandomColor());
        <% end %>
      <% end %>

      var chart = new Chart(ctx, {
        type: 'bar',
        data: {
          labels: labels,
          datasets: [{
            label: 'Respuestas',
            data: data,
            backgroundColor: backgroundColors
          }]
        },
        options: {
          scales: {
            y: {
              beginAtZero: true,
              ticks: {
                precision: 0
              }
            }
          }
        }
      });
    <% end %>
  });

  function getRandomColor() {
    var letters = '0123456789ABCDEF';
    var color = '#';
    for (var i = 0; i < 6; i++) {
      color += letters[Math.floor(Math.random() * 16)];
    }
    return color;
  }
</script>

# Incluir Chart.js en el layout (lib/survey_app_web/templates/layout/app.html.eex)
# Agregar antes del cierre de </head>:
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>

# CSS para mejorar la apariencia (priv/static/css/app.css)
/* Estilos para encuestas */
.surveys-list {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 20px;
  margin-top: 20px;
}

.survey-card {
  border: 1px solid #ddd;
  border-radius: 8px;
  padding: 20px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

.question {
  margin-bottom: 30px;
  padding: 15px;
  background-color: #f9f9f9;
  border-radius: 8px;
}

.option {
  margin: 10px 0;
}

.other-option {
  display: flex;
  align-items: center;
  margin-top: 10px;
}

.other-text {
  margin-left: 10px;
  flex-grow: 1;
}

.question-result {
  margin-bottom: 40px;
  padding: 20px;
  background-color: #f5f5f5;
  border-radius: 8px;
}

.chart-container {
  margin: 20px 0;
  max-width: 100%;
}

.other-answers {
  margin-top: 20px;
  padding: 15px;
  background-color: #fff;
  border: 1px solid #eee;
  border-radius: 5px;
}
