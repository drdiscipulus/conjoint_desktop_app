const statusMessage = document.querySelector("#status-message");

function setStatus(message, isError = false) {
  if (!statusMessage) {
    return;
  }
  statusMessage.textContent = message;
  statusMessage.classList.toggle("error", isError);
}

const tauriEvent = window.__TAURI__?.event;

if (tauriEvent?.listen) {
  tauriEvent.listen("shiny-startup-error", (event) => {
    const message = typeof event.payload === "string"
      ? event.payload
      : "The local Shiny app could not be started.";
    setStatus(message, true);
  });

  tauriEvent.listen("shiny-startup-status", (event) => {
    if (typeof event.payload === "string") {
      setStatus(event.payload);
    }
  });
}
