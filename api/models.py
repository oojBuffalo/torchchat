from typing import Any, Dict, List, Optional, Union


from dataclasses import dataclass

from download import is_model_downloaded, load_model_configs
from pwd import getpwuid

import os
import time

@dataclass
class ModelInfo:
    """Information about a model that can be used to generate completions."""
    id: str
    created: int
    owner: str 
    object: str = "model"


@dataclass
class ModelInfoResponse:
    """A list of models that can be used to generate completions."""
    data: List[ModelInfo]
    object: str = "list"


def get_model_info_list(args) -> ModelInfoResponse:
    """Returns a list of models that can be used to generate completions."""
    data = []
    for model_id, model_config in load_model_configs().items():
        model_dir = args.model_directory
        if is_model_downloaded(model_id, model_dir):
            path = model_dir / model_id
            created = int(os.path.getctime(path))
            owner = getpwuid(os.stat(path).st_uid).pw_name

            data.append(ModelInfo(id=model_config.name, created=created, owner = owner))
    response = ModelInfoResponse(data=data)
    return response
