document.addEventListener("DOMContentLoaded", () => {
  const btn = document.querySelector("button");
  if (!btn) return;

  btn.addEventListener("click", () => {
    alert("Button clicked!");
  });
});
