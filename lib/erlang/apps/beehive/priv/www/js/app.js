(function($) {

  $(function() {
    
    var opts = {
      plugins: ["Haml", "JSON"], 
      controllers: ["application", "apps", "bees", "events", "log", "overview", "users"]
    };
  
    RatPack(opts).run();
  });

})(jQuery);