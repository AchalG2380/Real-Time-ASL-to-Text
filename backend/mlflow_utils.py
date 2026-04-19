"""
mlflow_utils.py
===============
Shared MLflow tracking helpers for the ASL project.

Usage
-----
from mlflow_utils import ASLRun

with ASLRun("ASL-Letters", run_name="Conv1D_v2", params={...}, tags={...}) as run:
    history = model.fit(...)
    run.log_keras_history(history)
    run.log_eval(test_loss=0.01, test_accuracy=0.99)
    run.log_artifact_file("path/to/model.tflite")
"""

import os
import mlflow
import mlflow.keras
from typing import Any

# ── Default tracking URI ───────────────────────────────────────────────────
# Override by setting the MLFLOW_TRACKING_URI environment variable.
# Local default: ./mlruns  (MLflow creates this automatically)
TRACKING_URI = os.getenv("MLFLOW_TRACKING_URI", "file:./mlruns")
mlflow.set_tracking_uri(TRACKING_URI)


class ASLRun:
    """
    Context manager that wraps an MLflow run for any ASL model training.

    Parameters
    ----------
    experiment_name : str
        MLflow experiment name (e.g. "ASL-Letters", "ASL-Words").
    run_name : str
        Human-readable name for this specific training run.
    params : dict
        Hyperparameters and config logged as MLflow params.
        Common keys: epochs, batch_size, learning_rate, optimizer,
                     architecture, n_classes, n_samples, augment_factor, etc.
    tags : dict, optional
        Free-form key-value tags (e.g. {"dataset": "v3", "author": "achal"}).
    """

    def __init__(
        self,
        experiment_name: str,
        run_name: str,
        params: dict[str, Any] | None = None,
        tags: dict[str, str] | None = None,
    ):
        self.experiment_name = experiment_name
        self.run_name = run_name
        self.params = params or {}
        self.tags = tags or {}
        self._run = None

    # ── Context manager ───────────────────────────────────────────────────

    def __enter__(self):
        mlflow.set_experiment(self.experiment_name)
        self._run = mlflow.start_run(run_name=self.run_name)

        # Log all params
        for k, v in self.params.items():
            mlflow.log_param(k, v)

        # Log all tags
        for k, v in self.tags.items():
            mlflow.set_tag(k, v)

        print(f"[MLflow] Run started → {self.run_name}  "
              f"(experiment: {self.experiment_name})")
        print(f"[MLflow] Run ID: {self._run.info.run_id}")
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        if exc_type is not None:
            mlflow.set_tag("status", "FAILED")
            mlflow.set_tag("error", str(exc_val)[:250])
        else:
            mlflow.set_tag("status", "OK")
        mlflow.end_run()
        print(f"[MLflow] Run ended → {self.run_name}")
        return False  # don't suppress exceptions

    # ── Logging helpers ───────────────────────────────────────────────────

    def log_keras_history(self, history) -> None:
        """
        Log per-epoch metrics from a Keras History object.

        Logs: loss, val_loss, accuracy, val_accuracy (when available).
        """
        metric_keys = history.history.keys()
        for epoch, _ in enumerate(history.epoch):
            for key in metric_keys:
                mlflow.log_metric(
                    key.replace("accuracy", "acc"),   # shorter name
                    float(history.history[key][epoch]),
                    step=epoch,
                )

    def log_eval(self, test_loss: float, test_accuracy: float) -> None:
        """Log final evaluation metrics (post-training test set evaluation)."""
        mlflow.log_metric("test_loss", test_loss)
        mlflow.log_metric("test_acc",  test_accuracy)
        print(f"[MLflow] Logged — test_loss={test_loss:.4f}  "
              f"test_acc={test_accuracy:.4f}")

    def log_artifact_file(self, path: str) -> None:
        """
        Log a local file (e.g. .tflite, .h5, .json) as an MLflow artifact.
        The file is uploaded to the run's artifact store.
        """
        if os.path.exists(path):
            mlflow.log_artifact(path)
            print(f"[MLflow] Artifact logged: {os.path.basename(path)}")
        else:
            print(f"[MLflow] WARNING: artifact file not found — {path}")

    def log_keras_model(self, model, artifact_path: str = "model") -> None:
        """Log a Keras model object directly into MLflow."""
        mlflow.keras.log_model(model, artifact_path=artifact_path)
        print(f"[MLflow] Keras model logged to '{artifact_path}'")

    def log_metric(self, key: str, value: float, step: int | None = None) -> None:
        """Log a single named metric."""
        mlflow.log_metric(key, value, step=step)

    def log_param(self, key: str, value: Any) -> None:
        """Log a single named param."""
        mlflow.log_param(key, value)

    @property
    def run_id(self) -> str | None:
        return self._run.info.run_id if self._run else None
