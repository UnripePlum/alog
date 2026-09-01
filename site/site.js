/** identity에서 온 site/config.json을 화면에 붙인다. */
function bindConfig(c) {
  document.title = c.displayName;
  document.querySelectorAll("[data-bind='displayName']").forEach((el) => {
    el.textContent = c.displayName;
  });
  document.querySelectorAll("[data-bind-href]").forEach((el) => {
    const key = el.getAttribute("data-bind-href");
    const url = c[key];
    if (typeof url === "string" && url) el.setAttribute("href", url);
  });
  document.querySelectorAll("[data-app-file]").forEach((el) => {
    el.textContent = c.displayName + ".app";
  });
  const download = document.getElementById("download");
  if (download && c.downloadURL) download.setAttribute("href", c.downloadURL);
  const req = c.minOS + " 이상. 그 이하는 실행되지 않습니다.";
  const reqs = document.getElementById("reqs");
  if (reqs) reqs.textContent = c.minOS + " 이상 · dmg";
  const reqsCard = document.getElementById("reqs-card");
  if (reqsCard) reqsCard.textContent = req;
  const copy = document.getElementById("copy");
  if (copy) copy.textContent = c.copyright;
}

fetch("config.json")
  .then((r) => r.json())
  .then(bindConfig);
