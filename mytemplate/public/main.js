function createPdfButton(pdfHref) {
  var iconSvg = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' aria-hidden='true'><path fill='#fff' d='M6 2h9l5 5v13a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2z'/><path fill='#d32f2f' d='M15 2v5h5zM4 14h16v6H4z'/><path fill='#fff' d='M6.4 18.5h.9c.7 0 1.1-.3 1.1-.9 0-.6-.4-.9-1.1-.9h-.9v1.8zm0 .8V21H5.3v-5h2.1c1.3 0 2.1.6 2.1 1.7S8.7 19.4 7.4 19.4h-1zm4.7.8h-1.8v-5h1.8c1.5 0 2.5.9 2.5 2.5s-1 2.5-2.5 2.5zm-.7-.9h.6c.8 0 1.4-.5 1.4-1.6s-.6-1.6-1.4-1.6h-.6zm4 .9h-1.1v-5h3.1v.9h-2v1.2h1.8v.9h-1.8z'/></svg>";
  var iconData = "data:image/svg+xml," + encodeURIComponent(iconSvg);

  var p = document.createElement("p");
  p.className = "pdf-download";
  p.setAttribute("style", "margin:12px 0 20px;");

  var a = document.createElement("a");
  a.className = "pdf-download-btn";
  a.href = pdfHref;
  a.setAttribute("download", "");
  a.setAttribute(
    "style",
    "display:inline-flex;align-items:center;gap:8px;padding:8px 14px;border:1px solid #c7cdd4;border-radius:6px;background:#e5e7eb;color:#1f2937;text-decoration:none;font-weight:600;"
  );

  var img = document.createElement("img");
  img.src = iconData;
  img.width = 24;
  img.height = 24;
  img.alt = "";
  img.style.display = "block";

  var span = document.createElement("span");
  span.textContent = "Download PDF";

  a.appendChild(img);
  a.appendChild(span);
  p.appendChild(a);
  return p;
}

function addPdfButtonIfMissing() {
  if (document.querySelector(".pdf-download")) {
    return;
  }

  var article = document.querySelector("article");
  if (!article) {
    return;
  }

  var h1 = article.querySelector("h1");
  if (!h1) {
    return;
  }

  var path = window.location.pathname || "";
  if (!path.endsWith(".html")) {
    return;
  }
  if (path.endsWith("/index.html") || path.endsWith("/toc.html")) {
    return;
  }

  var pdfPath = "/pdf" + path.replace(/\.html$/i, ".pdf");
  var button = createPdfButton(pdfPath);

  if (h1.nextSibling) {
    h1.parentNode.insertBefore(button, h1.nextSibling);
  } else {
    h1.parentNode.appendChild(button);
  }
}

function renameBottomPdfLinks() {
  var links = document.querySelectorAll("a.pdf-link");
  links.forEach(function (a) {
    if ((a.textContent || "").trim() === "Download ICT Handbook") {
      return;
    }
    a.textContent = "Download ICT Handbook";
  });
}

function watchForPdfLinks() {
  if (!window.MutationObserver || !document.body) {
    return;
  }

  var observer = new MutationObserver(function () {
    renameBottomPdfLinks();
  });

  observer.observe(document.body, { childList: true, subtree: true });
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", function () {
    addPdfButtonIfMissing();
    renameBottomPdfLinks();
    watchForPdfLinks();
  });
} else {
  addPdfButtonIfMissing();
  renameBottomPdfLinks();
  watchForPdfLinks();
}

export default {};
