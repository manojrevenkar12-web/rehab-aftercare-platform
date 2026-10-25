# Serves the therapist console (web/, built into public/ by the Dockerfile) for any path that is
# not the API, so the browser's router can take it from there. Static assets are served by the
# public file server before this is reached.
class ConsoleController < ActionController::API
  def show
    index = Rails.public_path.join("index.html")
    if index.exist?
      response.headers["Cache-Control"] = "no-cache"
      send_file index, type: "text/html; charset=utf-8", disposition: "inline"
    else
      render plain: "The console is not built. Run `cd web && npm run build` and copy web/dist into public/, " \
                    "or use `npm run dev` in web/.", status: :not_found
    end
  end
end
