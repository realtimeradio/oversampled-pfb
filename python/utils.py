import numpy as np

TYPES = (str, 'int16', 'int32', int, float, 'complex128', bool)

TYPES_MAP = {
  # max representable is a 128 long string per buffer element
  'str'   : np.dtype((np.unicode_, 128)),
  'int16' : np.int16,
  'int32' : np.int32,
  'int'   : int,
  'float' : float,
  'cx'    : np.complex128,
  'bool'  : bool
}

TYPES_INIT = {
  'str'   : '-',
  'int16' : 0,
  'int32' : 0,
  'int'   : 0,
  'float' : 0.0,
  'cx'    : 0+0*1j,
  'bool'  : False
}

TYPES_STR_FMT = {
  'str'   : ':<4s',
  'int'   : ':<4d',
  'cx'    : ':<4g',
}
