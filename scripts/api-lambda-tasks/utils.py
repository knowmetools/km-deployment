import os


def env_list(param_name, delimiter=","):
    """
    Get a list of parameters from an environment variable. The list is
    expected to be delimited by the given character.

    Args:
        param_name:
            The name of the environment variable to read the list from.
        delimiter:
            The delimiter used to separate values in the environment
            variable. Defaults to a comma (``","``).

    Returns:
        A list containing the parsed elements from the environment
        variable.
    """
    raw_str = env_param(param_name, default='', required=False)

    return raw_str.split(delimiter) if raw_str else []


def env_param(param_name, default=None, required=True):
    """
    Get a parameter from the environment.

    Args:
        param_name:
            The name of the environment variable to read.
        default:
            The default value to return if the environment variable is
            not set.
        required:
            A boolean indicating if an error should be thrown if the
            environment variable is not set.

    Returns:
        The value of the environment variable with the given name. If
        the variable is not set and it is not required, ``default`` is
        returned.

    Raises:
        KeyError:
            If the ``required`` is ``True`` and the environment variable
            is not set.
    """
    if required:
        return os.environ[param_name]

    return os.getenv(param_name, default)
