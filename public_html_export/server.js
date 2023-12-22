const express = require('express');
const app = express();
const port = process.env.PORT || 3000; // Set the port number

// Serve the static files from the 'public' directory
app.use(function(req, res, next) {
    res.header("Cross-Origin-Embedder-Policy", "require-corp");
    res.header("Cross-Origin-Opener-Policy", "same-origin");
    next();
  });
  app.use(express.static('./'));

// Start the server
app.listen(port, () => {
  console.log(`Server listening on port http://localhost:3000/`);
});


