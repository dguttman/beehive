// ------------------------ //
// Application "Controller" //
// ------------------------ //

var application_controller = function(app) {
  this.element_selector = '#main';    

  this.get("#/", function(context) {
    this.redirect("#/overview");
  });

  this.helpers({
    get_token: function(email, password) {
      var auth = {};
      var auth_url = "/auth.json";
      var auth_params = {email: email, password: password};
  	  this.post_page(auth_url, auth_params, auth, "response");
  	  return auth.response.token;
    }
  });

};