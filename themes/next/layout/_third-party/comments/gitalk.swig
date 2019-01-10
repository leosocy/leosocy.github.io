{% if page.comments && theme.gitalk.enable %}
  <link rel="stylesheet" href="https://libs.cdnjs.net/gitalk/1.4.1/gitalk.min.css">
  <script src="https://libs.cdnjs.net/gitalk/1.4.1/gitalk.min.js"></script>
  <script src="https://libs.cdnjs.net/blueimp-md5/2.10.0/js/md5.min.js"></script>
   <script type="text/javascript">
        var gitalk = new Gitalk({
          clientID: '{{ theme.gitalk.ClientID }}',
          clientSecret: '{{ theme.gitalk.ClientSecret }}',
          repo: '{{ theme.gitalk.repo }}',
          owner: '{{ theme.gitalk.githubID }}',
          admin: ['{{ theme.gitalk.adminUser }}'],
          id: md5(location.pathname),
          distractionFreeMode: '{{ theme.gitalk.distractionFreeMode }}'
        })
        gitalk.render('gitalk-container')           
       </script>
{% endif %}

