<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
    </article>
    <%-- Mục lục tự dựng từ các thẻ h2 của văn bản (chỉ hiện trên màn hình rộng) --%>
    <nav class="legal-toc" id="legal-toc" aria-label="Mục lục"></nav>
  </main>
  <footer class="legal-foot">
    <span>© 2026 UTErSpace — Đồ án môn Lập trình Web, HCMUTE</span>
    <span>Liên hệ: <a href="mailto:support@uterspace.local">support@uterspace.local</a></span>
  </footer>
  <script>
  (function () {
    var toc = document.getElementById('legal-toc');
    var heads = document.querySelectorAll('.legal-doc h2');
    if (!heads.length) { toc.remove(); return; }
    var title = document.createElement('b');
    title.textContent = 'Mục lục';
    toc.appendChild(title);
    var ol = document.createElement('ol');
    heads.forEach(function (h, i) {
      if (!h.id) h.id = 'muc-' + (i + 1);
      var li = document.createElement('li'), a = document.createElement('a');
      a.href = '#' + h.id;
      a.textContent = h.textContent;
      li.appendChild(a);
      ol.appendChild(li);
    });
    toc.appendChild(ol);
  })();
  </script>
</body>
</html>
