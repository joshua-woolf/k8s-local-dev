def prometheus_datasource:
  {"type": "prometheus", "uid": "prometheus"};

def is_prometheus_datasource:
  if type == "object" then
    (.type? == "prometheus") or
    (.uid? == "prometheus") or
    ((.uid? // "") | test("PROMETHEUS|PROM|datasource"; "i"))
  elif type == "string" then
    test("PROMETHEUS|PROM|datasource"; "i")
  else
    false
  end;

walk(
  if type == "object" and has("datasource") and (.datasource | is_prometheus_datasource) then
    .datasource = prometheus_datasource
  else
    .
  end
)
| if .templating.list? then
    .templating.list |= map(
      if .type == "datasource" and
         (((.query // "") | tostring | test("prometheus"; "i")) or
          ((.name // "") | test("datasource|prometheus"; "i"))) then
        .current = {"selected": true, "text": "Prometheus", "value": "prometheus"}
        | .options = []
        | .query = "prometheus"
      else
        .
      end
    )
  else
    .
  end
| del(.__inputs, .__requires)
| .id = null
| .editable = false
| .version = 1
| .tags = (((.tags // []) + ["local-dev", "upstream"]) | unique)
