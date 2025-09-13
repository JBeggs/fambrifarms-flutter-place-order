#!/usr/bin/env python3
"""
Logging configuration for WhatsApp Order Processing System
Centralized logging setup with file rotation and structured output
"""

import logging
import logging.handlers
import sys
from pathlib import Path
from .settings import LOGGING_CONFIG

def setup_logging(name: str = 'whatsapp_server') -> logging.Logger:
    """
    Set up logging with file rotation and console output.
    
    Args:
        name: Logger name
        
    Returns:
        Configured logger instance
    """
    logger = logging.getLogger(name)
    
    # Avoid duplicate handlers if already configured
    if logger.handlers:
        return logger
    
    # Set logging level
    level = getattr(logging, LOGGING_CONFIG['level'].upper(), logging.INFO)
    logger.setLevel(level)
    
    # Create formatter
    formatter = logging.Formatter(LOGGING_CONFIG['format'])
    
    # Console handler
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(level)
    console_handler.setFormatter(formatter)
    logger.addHandler(console_handler)
    
    # File handler with rotation
    try:
        # Ensure log directory exists
        LOGGING_CONFIG['file_path'].parent.mkdir(parents=True, exist_ok=True)
        
        file_handler = logging.handlers.RotatingFileHandler(
            LOGGING_CONFIG['file_path'],
            maxBytes=LOGGING_CONFIG['max_file_size'],
            backupCount=LOGGING_CONFIG['backup_count']
        )
        file_handler.setLevel(level)
        file_handler.setFormatter(formatter)
        logger.addHandler(file_handler)
        
    except Exception as e:
        logger.warning(f"Could not set up file logging: {e}")
    
    return logger

def get_logger(name: str = None) -> logging.Logger:
    """
    Get a logger instance.
    
    Args:
        name: Logger name (defaults to calling module)
        
    Returns:
        Logger instance
    """
    if name is None:
        # Get the calling module name
        import inspect
        frame = inspect.currentframe().f_back
        name = frame.f_globals.get('__name__', 'whatsapp_server')
    
    return setup_logging(name)

class LoggerMixin:
    """Mixin class to add logging capability to any class."""
    
    @property
    def logger(self) -> logging.Logger:
        """Get logger for this class."""
        if not hasattr(self, '_logger'):
            self._logger = get_logger(f"{self.__class__.__module__}.{self.__class__.__name__}")
        return self._logger

def log_function_call(func):
    """Decorator to log function calls with parameters and execution time."""
    import functools
    import time
    
    @functools.wraps(func)
    def wrapper(*args, **kwargs):
        logger = get_logger(func.__module__)
        
        # Log function entry
        logger.debug(f"Calling {func.__name__} with args={args}, kwargs={kwargs}")
        
        start_time = time.time()
        try:
            result = func(*args, **kwargs)
            execution_time = time.time() - start_time
            logger.debug(f"{func.__name__} completed in {execution_time:.3f}s")
            return result
        except Exception as e:
            execution_time = time.time() - start_time
            logger.error(f"{func.__name__} failed after {execution_time:.3f}s: {e}")
            raise
    
    return wrapper

def log_performance(operation_name: str):
    """Decorator to log performance metrics for operations."""
    def decorator(func):
        import functools
        import time
        
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            logger = get_logger(func.__module__)
            
            start_time = time.time()
            start_memory = _get_memory_usage()
            
            try:
                result = func(*args, **kwargs)
                
                end_time = time.time()
                end_memory = _get_memory_usage()
                
                execution_time = end_time - start_time
                memory_delta = end_memory - start_memory if start_memory and end_memory else None
                
                logger.info(f"Performance [{operation_name}]: {execution_time:.3f}s" +
                           (f", memory: {memory_delta:+.1f}MB" if memory_delta else ""))
                
                return result
            except Exception as e:
                execution_time = time.time() - start_time
                logger.error(f"Performance [{operation_name}] FAILED after {execution_time:.3f}s: {e}")
                raise
        
        return wrapper
    return decorator

def _get_memory_usage():
    """Get current memory usage in MB."""
    try:
        import psutil
        import os
        process = psutil.Process(os.getpid())
        return process.memory_info().rss / 1024 / 1024  # Convert to MB
    except ImportError:
        return None

# Initialize root logger on import
setup_logging()
