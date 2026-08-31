/* ==========================================================================
   Portfolio behaviour. No dependencies, no build step.
   Three jobs: footer year, scroll-reveal, and active nav highlighting.
   Everything degrades to a fully readable page if it fails.
   ========================================================================== */

(function () {
  'use strict';

  /* -------------------------------------------------- footer year ------- */

  var yr = document.getElementById('yr');
  if (yr) {
    yr.textContent = String(new Date().getFullYear());
  }

  var sections = document.querySelectorAll('main section[id]');
  var reveals = document.querySelectorAll('.reveal');

  /* Older browsers, or anyone who has asked for reduced motion, get the
     final state straight away rather than a page of invisible sections. */
  var prefersReducedMotion = window.matchMedia
    ? window.matchMedia('(prefers-reduced-motion: reduce)').matches
    : false;

  function revealAll() {
    Array.prototype.forEach.call(reveals, function (el) {
      el.classList.add('in');
    });
  }

  if (!('IntersectionObserver' in window) || prefersReducedMotion) {
    revealAll();
    return;
  }

  /* -------------------------------------------------- scroll reveal ----- */

  var revealObserver = new IntersectionObserver(function (entries) {
    entries.forEach(function (entry) {
      if (!entry.isIntersecting) return;
      entry.target.classList.add('in');
      revealObserver.unobserve(entry.target);   // one-shot, never re-hides
    });
  }, {
    rootMargin: '0px 0px -10% 0px',
    threshold: 0.05
  });

  Array.prototype.forEach.call(reveals, function (el) {
    revealObserver.observe(el);
  });

  /* -------------------------------------------------- active nav link --- */

  var navLinks = Array.prototype.slice.call(document.querySelectorAll('.nav a'));
  var linkFor = {};

  navLinks.forEach(function (link) {
    var href = link.getAttribute('href') || '';
    if (href.charAt(0) === '#' && href.length > 1) {
      linkFor[href.slice(1)] = link;
    }
  });

  function setActive(link) {
    navLinks.forEach(function (a) { a.removeAttribute('aria-current'); });
    link.setAttribute('aria-current', 'true');
  }

  /* The negative bottom margin shrinks the observation band to a strip near
     the top of the viewport, so the highlighted link matches the section you
     are actually reading rather than whichever one is merely on screen. */
  var navObserver = new IntersectionObserver(function (entries) {
    entries.forEach(function (entry) {
      if (!entry.isIntersecting) return;
      var link = linkFor[entry.target.id];
      if (link) setActive(link);
    });
  }, {
    rootMargin: '-55px 0px -70% 0px'
  });

  Array.prototype.forEach.call(sections, function (section) {
    navObserver.observe(section);
  });
})();
