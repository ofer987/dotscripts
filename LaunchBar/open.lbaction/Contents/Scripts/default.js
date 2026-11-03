// LaunchBar Action Script

function run(argument) {
  if (!argument) {
    return;
  }

  args = argument.split(' ');

  let schema = args[0];
  switch (schema) {
    case 'https':
    case 'http':
      args = args.slice(1);
      break;
    default:
      schema = 'http';
  }

  if (args.length === 2) {
    let port = args[0];
    let path = args[1];

    if (path.startsWith('/')) {
      path = path.substring(1)
    }
    path = encodeURI(path);

    uri = `${schema}://localhost:${port}/${path}`;
  } else {
    let port = args[0];

    uri = `${schema}://localhost:${port}`;
  }

  LaunchBar.openURL(uri);
}
