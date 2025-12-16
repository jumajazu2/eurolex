this generates the package with correct values

dart run msix:create `
  --store `
  --display-name "LegisTracerEU" `
  --publisher-display-name "Jumajazu" `
  --identity-name "Jumajazu.LegisTracerEU" `
  --publisher "CN=9687351F-CD29-4738-A1E5-91A13D3AEBB4" `
  --version "0.9.0.0" `
  --logo-path "windows/runner/resources/app_icon.ico"

